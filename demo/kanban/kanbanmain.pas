unit kanbanmain;

(*
  Kanban board (like Trello) built with csscontrols: layout and look are Tailwind classes, icons are svg from
  Lucide. Cards are moved by drag and drop, detail dialog uses native LCL controls (TEdit, TMemo) placed in nodes,
  search and filters, dark mode. Tasks are saved to tasks.json in application config folder.
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, DateUtils, Contnrs, Controls, Forms, Graphics, StdCtrls, ExtCtrls, LCLType,
  Clipbrd, Dialogs, InterfaceBase, LCLPlatformDef, fpjson, jsonparser, cssbase, CSSCtrls, csshtml, kanbanicons;

type
  TCheckItem = record
    Text: String;
    Done: Boolean;
  end;

  { TTask }

  TTask = class
    Title, Description: String;
    Column: Integer;           // index in COLUMNS
    Priority: Integer;         // 0 low, 1 medium, 2 high
    Assignee: Integer;         // index in PEOPLE, -1 = nobody
    Labels: Integer;           // bits of LABELS
    Due: TDate;                // 0 = no due date
    Comments, Files: Integer;
    Checks: array of TCheckItem;
    function DoneChecks: Integer;
  end;

  { TKanbanForm }

  TKanbanForm = class(TForm)
  private
    FShape: TCSSShape;
    FTasks: TObjectList;       // order of tasks = order of cards in columns
    FToolbar, FBoard, FTheme: THtmlNode;
    FSearch: TEdit;
    FFilter: Integer;          // 0 all tasks, 1 assigned to me, 2 high priority
    // drag and drop of card
    FDownCard: THtmlNode;
    FDownPos, FGrab: TPoint;
    FDragging, FDragged: Boolean;
    FRebuildPending: Boolean;  // board is built again after drop (not in mouse events of nodes)
    FGhost: TCSSShape;         // dragged card: own small shape above board, only moved (board is not painted again)
    FGhostSize: TPoint;
    // detail dialog
    FModal, FPanel, FProps: THtmlNode;
    FModalTask: TTask;
    FModalColumn: Integer;     // column of task when dialog was opened
    FTitleEdit: TEdit;
    FDescMemo: TMemo;
    FStatsTimer: TTimer;
    FStatsLast: TCSSStats;
    FStatsTime: Double;
    FControlsMs: Double;       // benchmark: time of creating native controls of dialog
    function FileName: String;
    procedure LoadTasks;
    procedure SaveTasks;
    procedure SeedTasks;
    function Matches(T: TTask): Boolean;
    function CardHTML(T: TTask): String;
    function ColumnHTML(ACol: Integer): String;
    procedure Bind(ANode: THtmlNode);
    procedure BuildBoardAsync(Data: PtrInt);
    procedure BuildSidebar(AParent: THtmlNode);
    procedure BuildHeader(AParent: THtmlNode);
    procedure BuildToolbar;
    procedure BuildTheme;
    procedure BuildBoard;
    procedure BuildColumn(ACol: Integer);
    procedure HideFiltered(ANode: THtmlNode);
    procedure UpdateCounts;
    procedure UpdateControlColors;
    procedure ActionClick(Sender: TObject);
    procedure CardClick(Sender: TObject);
    procedure PanelClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure ShapeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ShapeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ShapeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure StartDrag(X, Y: Integer);
    procedure MoveDrag(X, Y: Integer);
    procedure EndDrag;
    procedure NewTask(ACol: Integer);
    procedure OpenTask(T: TTask);
    procedure BuildProps;
    procedure CloseTask;
    procedure TitleChange(Sender: TObject);
    procedure DescChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    // performance: F12 shows statistics in caption, F11 runs benchmark (result is copied to clipboard)
    procedure ToggleStats;
    procedure StatsTick(Sender: TObject);
    procedure RunBenchmark;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
  end;

var
  KanbanForm: TKanbanForm;

implementation

type
  TColumnInfo = record Name, Dot: String; end;
  TLabelInfo = record Name, Color: String; end;
  TPersonInfo = record Initials, Name, Gradient: String; end;

const
  COLUMNS: array[0..3] of TColumnInfo = (
    (Name: 'Backlog'; Dot: 'bg-slate-400'), (Name: 'To do'; Dot: 'bg-sky-500'),
    (Name: 'In progress'; Dot: 'bg-amber-500'), (Name: 'Done'; Dot: 'bg-emerald-500'));
  LABELS: array[0..5] of TLabelInfo = (
    (Name: 'Design'; Color: 'pink'), (Name: 'Frontend'; Color: 'sky'), (Name: 'Backend'; Color: 'violet'),
    (Name: 'Bug'; Color: 'rose'), (Name: 'Research'; Color: 'amber'), (Name: 'Marketing'; Color: 'emerald'));
  PEOPLE: array[0..4] of TPersonInfo = (
    (Initials: 'AM'; Name: 'Alex Morgan'; Gradient: 'from-indigo-500 to-violet-500'),
    (Initials: 'AK'; Name: 'Anna'; Gradient: 'from-pink-500 to-rose-500'),
    (Initials: 'MT'; Name: 'Martin'; Gradient: 'from-sky-500 to-cyan-500'),
    (Initials: 'LH'; Name: 'Lucia'; Gradient: 'from-amber-400 to-orange-500'),
    (Initials: 'JB'; Name: 'Jakub'; Gradient: 'from-emerald-500 to-teal-500'));
  PRIORITIES: array[0..2] of String = ('Low', 'Medium', 'High');
  ME = 0;

  CARD_CLASS = 'shrink-0 flex flex-col gap-3 p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 ' +
    'shadow-sm hover:shadow-md hover:border-slate-300 dark:hover:border-slate-700 hover:-translate-y-0.5 transition cursor-pointer';
  ICON_BUTTON = 'size-9 flex items-center justify-center rounded-xl text-slate-500 dark:text-slate-400 ' +
    'hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer';
  PILL = 'flex items-center gap-1.5 px-3 h-8 rounded-lg text-xs font-medium border transition-colors cursor-pointer ';
  PILL_ON = 'bg-indigo-50 border-indigo-200 text-indigo-700 dark:bg-indigo-500/15 dark:border-indigo-500/40 dark:text-indigo-200';
  PILL_OFF = 'bg-white border-slate-200 text-slate-600 hover:border-slate-300 hover:bg-slate-50 ' +
    'dark:bg-slate-900 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800';

function Esc(const S: String): String;
begin
  Result := StringReplace(StringReplace(StringReplace(S, '&', '&amp;', [rfReplaceAll]), '<', '&lt;', [rfReplaceAll]),
    '>', '&gt;', [rfReplaceAll]);
end;

function Avatar(APerson: Integer; const ASize: String): String;
begin
  Result := '<div class="' + ASize + ' shrink-0 flex items-center justify-center rounded-full bg-gradient-to-br ' +
    PEOPLE[APerson].Gradient + ' text-white font-semibold">' + PEOPLE[APerson].Initials + '</div>';
end;

function LabelPill(ALabel: Integer): String;
var
  C: String;
begin
  C := LABELS[ALabel].Color;
  Result := Format('<div class="px-2 py-0.5 rounded-md text-[11px] font-medium bg-%s-50 text-%s-700 ' +
    'dark:bg-%s-500/15 dark:text-%s-300">%s</div>', [C, C, C, C, LABELS[ALabel].Name]);
end;

{ TTask }

function TTask.DoneChecks: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Checks) do
    if Checks[I].Done then Inc(Result);
end;

{ TKanbanForm }

constructor TKanbanForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  Main: THtmlNode;
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'Flowboard';
  Width := 1360;
  Height := 860;
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  FTasks := TObjectList.Create(True);
  LoadTasks;

  FShape := TCSSShape.Create(Self);
  FShape.Parent := Self;
  FShape.Align := alClient;
  FShape.OnMouseDown := @ShapeMouseDown;
  FShape.OnMouseMove := @ShapeMouseMove;
  FShape.OnMouseUp := @ShapeMouseUp;
  CSSBeginUpdate;
  try
    FShape.Body.SetClass('h-full flex relative bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100');
    BuildSidebar(FShape.Body);
    Main := HTMLNode('flex-1 min-w-0 flex flex-col').AppendTo(FShape.Body);
    BuildHeader(Main);
    FToolbar := HTMLNode('flex items-center gap-2 px-8 pb-5').AppendTo(Main);
    FBoard := HTMLNode('flex-1 min-h-0 flex gap-4 px-8 pb-8 overflow-x-auto').AppendTo(Main);
    BuildToolbar;
    BuildBoard;
  finally
    CSSEndUpdate;          // shape is laid out once here
  end;
  UpdateControlColors;
end;

destructor TKanbanForm.Destroy;
begin
  FTasks.Free;
  inherited Destroy;
end;

{ tasks }

function TKanbanForm.FileName: String;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'tasks.json';
end;

procedure TKanbanForm.LoadTasks;
var
  Data: TJSONData;
  O: TJSONObject;
  A: TJSONArray;
  T: TTask;
  I, J: Integer;
  S: TStringList;
begin
  if not FileExists(FileName) then begin
    SeedTasks;
    Exit;
  end;
  S := TStringList.Create;
  try
    S.LoadFromFile(FileName);
    Data := GetJSON(S.Text);
  finally
    S.Free;
  end;
  try
    if Data is TJSONArray then
      for I := 0 to TJSONArray(Data).Count - 1 do begin
        O := TJSONArray(Data).Objects[I];
        T := TTask.Create;
        T.Title := O.Get('title', '');
        T.Description := O.Get('description', '');
        T.Column := EnsureRange(O.Get('column', 0), 0, High(COLUMNS));
        T.Priority := EnsureRange(O.Get('priority', 1), 0, 2);
        T.Assignee := EnsureRange(O.Get('assignee', -1), -1, High(PEOPLE));
        T.Labels := O.Get('labels', 0);
        T.Due := O.Get('due', 0.0);
        T.Comments := O.Get('comments', 0);
        T.Files := O.Get('files', 0);
        if O.Find('checks') is TJSONArray then begin
          A := TJSONArray(O.Find('checks'));
          SetLength(T.Checks, A.Count);
          for J := 0 to A.Count - 1 do begin
            T.Checks[J].Text := A.Objects[J].Get('text', '');
            T.Checks[J].Done := A.Objects[J].Get('done', False);
          end;
        end;
        FTasks.Add(T);
      end;
  finally
    Data.Free;
  end;
end;

procedure TKanbanForm.SaveTasks;
var
  Arr, Checks: TJSONArray;
  O: TJSONObject;
  T: TTask;
  I, J: Integer;
  S: TStringList;
begin
  Arr := TJSONArray.Create;
  S := TStringList.Create;
  try
    for I := 0 to FTasks.Count - 1 do begin
      T := TTask(FTasks[I]);
      Checks := TJSONArray.Create;
      for J := 0 to High(T.Checks) do
        Checks.Add(TJSONObject.Create(['text', T.Checks[J].Text, 'done', T.Checks[J].Done]));
      O := TJSONObject.Create(['title', T.Title, 'description', T.Description, 'column', T.Column,
        'priority', T.Priority, 'assignee', T.Assignee, 'labels', T.Labels, 'due', Double(T.Due),
        'comments', T.Comments, 'files', T.Files]);
      O.Add('checks', Checks);
      Arr.Add(O);
    end;
    ForceDirectories(ExtractFilePath(FileName));
    S.Text := Arr.FormatJSON;
    S.SaveToFile(FileName);
  finally
    S.Free;
    Arr.Free;
  end;
end;

procedure TKanbanForm.SeedTasks;
  procedure Add(const ATitle, ADesc: String; ACol, APrio, AWho, ALabels, ADays, AComments, AFiles: Integer;
    const AChecks: array of String; ADone: Integer);
  var
    T: TTask;
    I: Integer;
  begin
    T := TTask.Create;
    T.Title := ATitle;
    T.Description := ADesc;
    T.Column := ACol;
    T.Priority := APrio;
    T.Assignee := AWho;
    T.Labels := ALabels;
    if ADays <> 999 then T.Due := Date + ADays;
    T.Comments := AComments;
    T.Files := AFiles;
    SetLength(T.Checks, Length(AChecks));
    for I := 0 to High(AChecks) do begin
      T.Checks[I].Text := AChecks[I];
      T.Checks[I].Done := I < ADone;
    end;
    FTasks.Add(T);
  end;
begin
  Add('Competitor pricing research', 'Compare plans and limits of five closest competitors.', 0, 0, 3, 16, 12, 2, 1, [], 0);
  Add('Referral program concept', '', 0, 1, 1, 32 or 1, 999, 0, 0, [], 0);
  Add('Accessibility audit of checkout', 'Keyboard navigation, focus states and contrast of all steps.', 0, 1, -1, 2, 20, 1, 0,
    ['Keyboard', 'Screen reader', 'Contrast'], 0);
  Add('Design onboarding flow', 'Three steps with progress, skip option and friendly empty states.', 1, 2, 1, 1 or 2, 2, 5, 3,
    ['Wireframes', 'Visual design', 'Prototype', 'Usability test'], 1);
  Add('Pricing page copy', 'Short, benefit first. Ask marketing for the final numbers.', 1, 1, 0, 32, 4, 3, 0, [], 0);
  Add('Fix login redirect loop', 'Happens after session timeout on Safari only.', 1, 2, 2, 8 or 4, -1, 7, 1, [], 0);
  Add('Billing API: invoices endpoint', 'Paginated list with PDF links, filters by status and date.', 2, 2, 0, 4, 1, 4, 2,
    ['Schema', 'Endpoint', 'Tests', 'Docs', 'Review'], 3);
  Add('Dashboard charts', 'Revenue and active users, dark mode friendly colors.', 2, 1, 2, 2 or 1, 6, 2, 4,
    ['Line chart', 'Bar chart', 'Legend'], 2);
  Add('Launch email sequence', '', 2, 1, 3, 32, 9, 1, 0, ['Welcome', 'Tips', 'Upgrade'], 1);
  Add('Set up error monitoring', 'Alerts to the team channel for new issues.', 3, 1, 4, 4, -3, 2, 0, ['Install', 'Alerts'], 2);
  Add('Brand colors and type scale', '', 3, 0, 1, 1, -6, 6, 5, [], 0);
  Add('Landing page hero', 'Headline, product shot and two calls to action.', 3, 2, 0, 1 or 2 or 32, -2, 9, 2,
    ['Copy', 'Illustration', 'Responsive'], 3);
end;

function TKanbanForm.Matches(T: TTask): Boolean;
var
  Q: String;
  I: Integer;
begin
  Result := (FFilter = 0) or ((FFilter = 1) and (T.Assignee = ME)) or ((FFilter = 2) and (T.Priority = 2));
  if not Result or (FSearch = nil) or (Trim(FSearch.Text) = '') then Exit;
  Q := LowerCase(Trim(FSearch.Text));
  Result := (Pos(Q, LowerCase(T.Title)) > 0) or (Pos(Q, LowerCase(T.Description)) > 0);
  for I := 0 to High(LABELS) do
    if (T.Labels and (1 shl I) <> 0) and (Pos(Q, LowerCase(LABELS[I].Name)) > 0) then Result := True;
end;

{ markup }

function TKanbanForm.CardHTML(T: TTask): String;
var
  I, Done: Integer;
  S, DueCls: String;
begin
  Result := '<div class="' + CARD_CLASS + '" data-task="' + IntToStr(FTasks.IndexOf(T)) + '">';
  if T.Labels <> 0 then begin
    Result := Result + '<div class="flex flex-wrap gap-1.5">';
    for I := 0 to High(LABELS) do
      if T.Labels and (1 shl I) <> 0 then Result := Result + LabelPill(I);
    Result := Result + '</div>';
  end;
  // title (done tasks are checked and muted)
  Result := Result + '<div class="flex items-start gap-2">';
  if T.Column = High(COLUMNS) then
    Result := Result + SvgIcon(icCircleCheckBig, 'size-4 shrink-0 mt-0.5 text-emerald-500') +
      '<div class="flex-1 min-w-0 text-sm font-medium text-slate-400 dark:text-slate-500 line-clamp-2">' + Esc(T.Title) + '</div>'
  else
    Result := Result + '<div class="flex-1 min-w-0 text-sm font-medium text-slate-800 dark:text-slate-100 line-clamp-2">' +
      Esc(T.Title) + '</div>';
  if T.Priority = 2 then Result := Result + SvgIcon(icFlag, 'size-4 shrink-0 mt-0.5 text-rose-500');
  Result := Result + '</div>';
  if T.Description <> '' then
    Result := Result + '<div class="text-xs text-slate-500 dark:text-slate-400 line-clamp-2">' + Esc(T.Description) + '</div>';
  // checklist progress
  if Length(T.Checks) > 0 then begin
    Done := T.DoneChecks;
    if Done = Length(T.Checks) then S := 'bg-emerald-500' else S := 'bg-indigo-500';
    Result := Result + Format('<div class="flex flex-col gap-1.5"><div class="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">' +
      '%s<div class="flex-1">Checklist</div><div>%d/%d</div></div>' +
      '<div class="h-1.5 rounded-full bg-slate-100 dark:bg-slate-800"><div class="h-1.5 rounded-full %s" style="width: %d%%"></div></div></div>',
      [SvgIcon(icListChecks, 'size-3.5'), Done, Length(T.Checks), S, Round(Done / Length(T.Checks) * 100)]);
  end;
  // footer: due date, comments, files, assignee
  Result := Result + '<div class="flex items-center gap-3 text-xs text-slate-400 dark:text-slate-500 whitespace-nowrap">';
  if T.Due > 0 then begin
    if T.Column = High(COLUMNS) then DueCls := 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
    else if T.Due < Date then DueCls := 'bg-rose-50 text-rose-600 dark:bg-rose-500/15 dark:text-rose-300'
    else if T.Due <= Date + 2 then DueCls := 'bg-amber-50 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300'
    else DueCls := 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300';
    Result := Result + '<div class="shrink-0 flex items-center gap-1 px-2 py-1 rounded-md font-medium whitespace-nowrap ' + DueCls + '">' +
      SvgIcon(icClock, 'size-3.5') + FormatDateTime('mmm d', T.Due) + '</div>';
  end;
  if T.Comments > 0 then
    Result := Result + '<div class="flex items-center gap-1">' + SvgIcon(icMessageSquare, 'size-3.5') + IntToStr(T.Comments) + '</div>';
  if T.Files > 0 then
    Result := Result + '<div class="flex items-center gap-1">' + SvgIcon(icPaperclip, 'size-3.5') + IntToStr(T.Files) + '</div>';
  Result := Result + '<div class="flex-1"></div>';
  if T.Assignee >= 0 then Result := Result + Avatar(T.Assignee, 'size-6 text-[10px]');
  Result := Result + '</div></div>';
end;

function TKanbanForm.ColumnHTML(ACol: Integer): String;
var
  I: Integer;
begin
  Result := Format('<div class="flex-1 min-w-60 max-w-80 flex flex-col rounded-2xl bg-slate-100 dark:bg-slate-900/60 ' +
    'border border-slate-200/70 dark:border-slate-800" data-col="%d">' +
    '<div class="flex items-center gap-2 pl-4 pr-2 pt-3 pb-2">' +
    '<div class="size-2 rounded-full %s"></div>' +
    '<div class="text-sm font-semibold text-slate-700 dark:text-slate-200">%s</div>' +
    '<div class="px-2 py-0.5 rounded-full bg-white dark:bg-slate-800 text-xs font-medium text-slate-500 dark:text-slate-400" data-count="%d">0</div>' +
    '<div class="flex-1"></div>' +
    '<div class="size-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-white dark:hover:bg-slate-800 ' +
    'hover:text-slate-700 dark:hover:text-white transition-colors cursor-pointer" data-action="add" data-v="%d">%s</div>' +
    '</div><div class="flex-1 min-h-0 flex flex-col gap-3 px-3 pb-3 overflow-y-auto" data-list="%d">',
    [ACol, COLUMNS[ACol].Dot, COLUMNS[ACol].Name, ACol, ACol, SvgIcon(icPlus, 'size-4'), ACol]);
  for I := 0 to FTasks.Count - 1 do
    if TTask(FTasks[I]).Column = ACol then Result := Result + CardHTML(TTask(FTasks[I]));
  // add button is the last item of list (right after cards)
  Result := Result + Format('<div class="shrink-0 flex items-center gap-2 px-3 py-2 rounded-xl text-sm text-slate-500 ' +
    'dark:text-slate-400 hover:bg-white dark:hover:bg-slate-800 hover:text-slate-800 dark:hover:text-white transition-colors ' +
    'cursor-pointer" data-action="add" data-v="%d">%sAdd task</div></div></div>', [ACol, SvgIcon(icPlus, 'size-4')]);
end;

(*
  Click handlers and data of nodes from markup: cards (data-task), actions (data-action)
*)
procedure TKanbanForm.Bind(ANode: THtmlNode);
var
  C: THtmlNode;
begin
  if ANode.Attributes['data-task'] <> '' then begin
    ANode.Data := FTasks[StrToInt(ANode.Attributes['data-task'])];
    ANode.OnClick := @CardClick;
  end else if ANode.Attributes['data-action'] <> '' then
    ANode.OnClick := @ActionClick;
  C := ANode.FirstChild;
  while Assigned(C) do begin
    Bind(C);
    C := ANode.GetNext(C);
  end;
end;

(*
  First node in subtree with attribute
*)
function FindByAttr(ANode: THtmlNode; const AName: String): THtmlNode;
var
  C: THtmlNode;
begin
  if ANode.Attributes[AName] <> '' then Exit(ANode);
  C := ANode.FirstChild;
  while Assigned(C) do begin
    Result := FindByAttr(C, AName);
    if Assigned(Result) then Exit;
    C := ANode.GetNext(C);
  end;
  Result := nil;
end;

procedure TKanbanForm.BuildSidebar(AParent: THtmlNode);
  function NavItem(AIcon: TIconName; const AName, ABadge: String; AActive: Boolean): String;
  begin
    if AActive then
      Result := '<div class="flex items-center gap-3 px-3 h-9 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white text-sm font-medium">'
    else
      Result := '<div class="flex items-center gap-3 px-3 h-9 rounded-lg text-slate-500 dark:text-slate-400 hover:bg-slate-50 ' +
        'dark:hover:bg-slate-800/60 hover:text-slate-900 dark:hover:text-white text-sm transition-colors cursor-pointer">';
    Result := Result + SvgIcon(AIcon, 'size-[18px]') + '<div class="flex-1">' + AName + '</div>';
    if ABadge <> '' then
      Result := Result + '<div class="px-1.5 rounded-md bg-indigo-600 text-white text-[11px] font-semibold">' + ABadge + '</div>';
    Result := Result + '</div>';
  end;
  function BoardItem(const AColor, AName: String; AActive: Boolean): String;
  begin
    if AActive then Result := '<div class="flex items-center gap-3 px-3 h-8 rounded-lg text-sm font-medium text-slate-900 dark:text-white">'
      else Result := '<div class="flex items-center gap-3 px-3 h-8 rounded-lg text-sm text-slate-500 dark:text-slate-400 ' +
        'hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer">';
    Result := Result + '<div class="size-2.5 rounded-sm ' + AColor + '"></div>' + AName + '</div>';
  end;
var
  Side: THtmlNode;
begin
  Side := HTMLNode('w-64 shrink-0 flex flex-col gap-7 px-4 py-6 bg-white dark:bg-slate-900 border-r border-slate-200 ' +
    'dark:border-slate-800').AppendTo(AParent);
  Side.AppendHTML(
    '<div class="flex items-center gap-3 px-2">' +
    '<div class="size-10 flex items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 ' +
    'shadow-md shadow-indigo-500/30">' + SvgIcon(icSquareKanban, 'size-5 text-white') + '</div>' +
    '<div class="flex flex-col"><div class="text-[15px] font-semibold">Flowboard</div>' +
    '<div class="text-xs text-slate-400">Acme workspace</div></div></div>' +
    '<div class="flex flex-col gap-1">' +
    NavItem(icLayoutDashboard, 'Overview', '', False) + NavItem(icSquareKanban, 'Boards', '', True) +
    NavItem(icListTodo, 'My tasks', '', False) + NavItem(icInbox, 'Inbox', '3', False) +
    NavItem(icCalendar, 'Calendar', '', False) + NavItem(icUsers, 'Team', '', False) + '</div>' +
    '<div class="flex flex-col gap-1"><div class="px-3 pb-1 text-[11px] font-semibold text-slate-400">FAVORITE BOARDS</div>' +
    BoardItem('bg-indigo-500', 'Product launch', True) + BoardItem('bg-pink-500', 'Marketing site', False) +
    BoardItem('bg-amber-500', 'Mobile app', False) + BoardItem('bg-emerald-500', 'Customer success', False) + '</div>');
  // upgrade card and theme switch at bottom
  Side.AppendHTML(
    '<div class="mt-auto flex flex-col gap-3 p-4 rounded-2xl bg-gradient-to-br from-indigo-50 to-violet-50 ' +
    'dark:from-indigo-500/10 dark:to-violet-500/10 border border-indigo-100 dark:border-indigo-500/20">' +
    '<div class="flex items-center gap-2 text-indigo-600 dark:text-indigo-300">' + SvgIcon(icSparkles, 'size-4') +
    '<div class="text-sm font-semibold">Flowboard Pro</div></div>' +
    '<div class="text-xs text-slate-500 dark:text-slate-400">Timeline view, automations and unlimited boards.</div></div>');
  FTheme := HTMLNode('flex items-center gap-3 px-2').AppendTo(Side);
  BuildTheme;
end;

procedure TKanbanForm.BuildTheme;
var
  I: TIconName;
begin
  FTheme.Clear;
  if CSSDarkMode then I := icSun else I := icMoon;
  FTheme.AppendHTML(Avatar(ME, 'size-9 text-xs') +
    '<div class="flex-1 flex flex-col"><div class="text-sm font-medium">Alex Morgan</div>' +
    '<div class="text-xs text-slate-400">Admin</div></div>' +
    '<div class="' + ICON_BUTTON + '" data-action="theme">' + SvgIcon(I, 'size-[18px]') + '</div>');
  Bind(FTheme);
end;

procedure TKanbanForm.BuildHeader(AParent: THtmlNode);
var
  Head: THtmlNode;
  I: Integer;
  S: String;
begin
  S := '';
  for I := 1 to High(PEOPLE) do
    S := S + '<div class="-ml-2 first:ml-0 rounded-full ring-2 ring-slate-50 dark:ring-slate-950">' + Avatar(I, 'size-8 text-[11px]') + '</div>';
  Head := HTMLNode('flex items-center gap-4 px-8 pt-7 pb-5').AppendTo(AParent);
  Head.AppendHTML(
    '<div class="flex flex-col gap-1.5">' +
    '<div class="flex items-center gap-2 text-xs text-slate-400"><div>Boards</div><div>/</div>' +
    '<div class="text-slate-600 dark:text-slate-300">Product launch</div></div>' +
    '<div class="flex items-center gap-3"><div class="text-2xl font-semibold">Product launch</div>' +
    '<div class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-500/15 text-emerald-700 ' +
    'dark:text-emerald-300 text-xs font-medium"><div class="size-1.5 rounded-full bg-emerald-500"></div>On track</div></div></div>' +
    '<div class="flex-1"></div>' +
    '<div class="flex items-center pl-2">' + S + '</div>' +
    '<div class="w-64 h-10 flex items-center gap-2 px-3 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 ' +
    'dark:border-slate-800 text-slate-400 focus-within:border-indigo-400 focus-within:ring-4 focus-within:ring-indigo-500/15">' +
    SvgIcon(icSearch, 'size-4 shrink-0') + '<div class="flex-1 h-6" id="search"></div></div>' +
    '<div class="' + ICON_BUTTON + ' relative">' + SvgIcon(icBell, 'size-[18px]') +
    '<div class="absolute top-2 right-2 size-2 rounded-full bg-rose-500 ring-2 ring-slate-50 dark:ring-slate-950"></div></div>' +
    '<div class="h-10 flex items-center gap-2 pl-3 pr-4 rounded-xl bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 ' +
    'text-white text-sm font-semibold shadow-md shadow-indigo-500/25 transition-colors cursor-pointer" data-action="new">' +
    SvgIcon(icPlus, 'size-4') + 'New task</div>');
  Bind(Head);
  FSearch := TEdit.Create(Self);
  FSearch.Parent := Self;
  FSearch.BorderStyle := bsNone;
  FSearch.TextHint := 'Search tasks...';
  FSearch.OnChange := @SearchChange;
  Head.GetElementById('search').SetAlignControl(FSearch);
end;

procedure TKanbanForm.BuildToolbar;
  function Chip(AIndex: Integer; AIcon: TIconName; const AName: String): String;
  begin
    if FFilter = AIndex then Result := PILL + PILL_ON else Result := PILL + PILL_OFF;
    Result := '<div class="' + Result + '" data-action="filter" data-v="' + IntToStr(AIndex) + '">' +
      SvgIcon(AIcon, 'size-3.5') + AName + '</div>';
  end;
var
  I, Done: Integer;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    Done := 0;
    for I := 0 to FTasks.Count - 1 do
      if TTask(FTasks[I]).Column = High(COLUMNS) then Inc(Done);
    FToolbar.Clear;
    FToolbar.AppendHTML(Chip(0, icSquareKanban, 'All tasks') + Chip(1, icUserRound, 'Assigned to me') +
      Chip(2, icFlag, 'High priority') + '<div class="flex-1"></div>' +
      Format('<div class="flex items-center gap-3 text-xs text-slate-500 dark:text-slate-400"><div>%d tasks, %d done</div>' +
      '<div class="w-32 h-1.5 rounded-full bg-slate-200 dark:bg-slate-800"><div class="h-1.5 rounded-full bg-gradient-to-r ' +
      'from-indigo-500 to-violet-500" style="width: %d%%"></div></div></div>',
      [FTasks.Count, Done, Round(Done / Max(1, FTasks.Count) * 100)]));
    Bind(FToolbar);
  finally
    CSSEndUpdate;
  end;
end;

(*
  Filtered cards are hidden
*)
procedure TKanbanForm.HideFiltered(ANode: THtmlNode);
var
  C: THtmlNode;
begin
  if (ANode.Data is TTask) and not Matches(TTask(ANode.Data)) then ANode.SetClass(CARD_CLASS + ' hidden');
  C := ANode.FirstChild;
  while Assigned(C) do begin
    HideFiltered(C);
    C := ANode.GetNext(C);
  end;
end;

(*
  One column is built again (new column node replaces old one)
*)
procedure TKanbanForm.BuildColumn(ACol: Integer);
var
  Old, New: THtmlNode;
  I: Integer;
begin
  Old := FBoard.FirstChild;
  for I := 1 to ACol do
    if Assigned(Old) then Old := FBoard.GetNext(Old);
  if Old = nil then Exit;
  CSSBeginUpdate;
  try
    FBoard.AppendHTML(ColumnHTML(ACol));
    New := Old;
    while Assigned(FBoard.GetNext(New)) do New := FBoard.GetNext(New);    // appended column is the last one
    FBoard.InsertBefore(New, Old);
    FBoard.Delete(Old);
    Bind(New);
    HideFiltered(New);
    UpdateCounts;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.BuildBoard;
var
  I: Integer;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    FBoard.Clear;
    for I := 0 to High(COLUMNS) do
      FBoard.AppendHTML(ColumnHTML(I));
    Bind(FBoard);
    HideFiltered(FBoard);
    UpdateCounts;
    FShape.Changed;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.UpdateCounts;
var
  Col, C: THtmlNode;
  Count: Integer;
begin
  Col := FBoard.FirstChild;
  while Assigned(Col) do begin
    Count := 0;
    C := FindByAttr(Col, 'data-list').FirstChild;
    while Assigned(C) do begin
      if (C.Data is TTask) and not C.ClassList.Contains('hidden') then Inc(Count);
      C := C.ParentNode.GetNext(C);
    end;
    FindByAttr(Col, 'data-count').Text := IntToStr(Count);
    Col := FBoard.GetNext(Col);
  end;
end;

procedure TKanbanForm.BuildBoardAsync(Data: PtrInt);
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    if not FRebuildPending or FDragging or Assigned(FDownCard) then Exit;   // done later (next mouse down)
    FRebuildPending := False;
    BuildToolbar;
    BuildBoard;
  finally
    CSSEndUpdate;
  end;
end;

(*
  Native controls get colors of their nodes (dark mode)
*)
procedure TKanbanForm.UpdateControlColors;
  procedure SetColors(AControl: TCustomEdit; ADark, ALight: TColor);
  begin
    if AControl = nil then Exit;
    if CSSDarkMode then begin
      AControl.Color := ADark;
      AControl.Font.Color := RGBToColor(241, 245, 249);
    end else begin
      AControl.Color := ALight;
      AControl.Font.Color := RGBToColor(15, 23, 42);
    end;
  end;
begin
  SetColors(FSearch, RGBToColor(15, 23, 42), clWhite);
  SetColors(FTitleEdit, RGBToColor(15, 23, 42), clWhite);
  SetColors(FDescMemo, RGBToColor(30, 41, 59), RGBToColor(248, 250, 252));
end;

{ events }

procedure TKanbanForm.ActionClick(Sender: TObject);
var
  A: String;
  V: Integer;
  T: TTask;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    A := THtmlNode(Sender).Attributes['data-action'];
    V := StrToIntDef(THtmlNode(Sender).Attributes['data-v'], 0);
    T := FModalTask;
    if A = 'theme' then begin
      CSSSetDarkMode(not CSSDarkMode);
      BuildTheme;
      UpdateControlColors;
      FShape.Changed;
    end
    else if A = 'filter' then begin
      FFilter := V;
      BuildToolbar;
      BuildBoard;
    end
    else if A = 'new' then NewTask(1)
    else if A = 'add' then NewTask(V)
    else if A = 'close' then CloseTask
    else if Assigned(T) then begin
      if A = 'delete' then begin
        FModalTask := nil;
        FTasks.Remove(T);
        CloseTask;
        Exit;
      end;
      if A = 'status' then T.Column := V
      else if A = 'priority' then T.Priority := V
      else if A = 'assignee' then begin
        if T.Assignee = V then T.Assignee := -1 else T.Assignee := V;
      end
      else if A = 'label' then T.Labels := T.Labels xor (1 shl V)
      else if A = 'check' then T.Checks[V].Done := not T.Checks[V].Done;
      BuildProps;
    end;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.CardClick(Sender: TObject);
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    if FDragged then Exit;      // mouse up after drag and drop
    OpenTask(TTask(THtmlNode(Sender).Data));
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.PanelClick(Sender: TObject);
begin
  // click in dialog panel doesn't close it (backdrop closes it)
end;

procedure TKanbanForm.SearchChange(Sender: TObject);
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    BuildBoard;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and Assigned(FModal) then begin
    CloseTask;
    Key := 0;
  end;
  if Key = VK_F12 then begin
    ToggleStats;
    Key := 0;
  end;
  if Key = VK_F11 then begin
    RunBenchmark;
    Key := 0;
  end;
end;

{ performance }

procedure TKanbanForm.ToggleStats;
begin
  if FStatsTimer = nil then begin
    FStatsTimer := TTimer.Create(Self);
    FStatsTimer.Interval := 500;
    FStatsTimer.OnTimer := @StatsTick;
    FStatsTimer.Enabled := False;
  end;
  FStatsTimer.Enabled := not FStatsTimer.Enabled;
  FStatsLast := CSSStats;
  FStatsTime := CSSTimeMs;
  if not FStatsTimer.Enabled then Caption := 'Flowboard';
end;

(*
  Statistics of last half second: paints and layouts per second, average and max time, painted area,
  bitmaps and texts per paint, share of time spent in engine
*)
procedure TKanbanForm.StatsTick(Sender: TObject);
var
  Paints, Layouts: Integer;
  Ms, PaintMs, LayoutMs, Area: Double;
begin
  Ms := Max(1, CSSTimeMs - FStatsTime);
  Paints := CSSStats.Paints - FStatsLast.Paints;
  Layouts := CSSStats.Layouts - FStatsLast.Layouts;
  PaintMs := CSSStats.PaintMs - FStatsLast.PaintMs;
  LayoutMs := CSSStats.LayoutMs - FStatsLast.LayoutMs;
  if Paints > 0 then begin
    Area := (CSSStats.PaintPixels - FStatsLast.PaintPixels) / Paints / Max(1, FShape.Width * FShape.Height) * 100;
    Caption := Format('Flowboard  |  paint %.0f/s %.1f ms (max %.1f) %.0f%% of window, %d bitmaps %d texts  |  ' +
      'layout %.0f/s %.1f ms  |  engine %.0f%% of time', [Paints * 1000 / Ms, PaintMs / Paints, CSSStats.MaxPaintMs, Area,
      (CSSStats.Bitmaps - FStatsLast.Bitmaps) div Paints, (CSSStats.Texts - FStatsLast.Texts) div Paints,
      Layouts * 1000 / Ms, LayoutMs / Max(1, Layouts), (PaintMs + LayoutMs) / Ms * 100])
  end else
    Caption := Format('Flowboard  |  no paint  |  layout %.0f/s %.1f ms', [Layouts * 1000 / Ms, LayoutMs / Max(1, Layouts)]);
  CSSStats.MaxPaintMs := 0;
  FStatsLast := CSSStats;
  FStatsTime := CSSTimeMs;
end;

type
  TShapeAccess = class(TCSSShape);    // benchmark moves mouse over shape (protected MouseMove)

(*
  Benchmark: layout, full repaint, layout with repaint, detail dialog, hover and drag of card.
  Board is built again from tasks at the end (tasks are not changed).
*)
procedure TKanbanForm.RunBenchmark;
var
  Lines: TStringList;
  S0: TCSSStats;
  T: Double;
  I: Integer;
  Card: THtmlNode;
  P: TPointF;
  X, Y: Integer;
  procedure Start;
  begin
    CSSStats.MaxPaintMs := 0;
    S0 := CSSStats;
    T := CSSTimeMs;
  end;
  procedure Report(const AName: String; ASteps: Integer);
  var
    Paints, Layouts: Integer;
  begin
    T := CSSTimeMs - T;
    Paints := CSSStats.Paints - S0.Paints;
    Layouts := CSSStats.Layouts - S0.Layouts;
    Lines.Add(Format('%-16s %6.1f ms per step | %3d paints %5.1f ms (max %5.1f), %4d bitmaps %3d texts per paint | %3d layouts %5.1f ms',
      [AName, T / ASteps, Paints, (CSSStats.PaintMs - S0.PaintMs) / Max(1, Paints), CSSStats.MaxPaintMs,
      (CSSStats.Bitmaps - S0.Bitmaps) div Max(1, Paints), (CSSStats.Texts - S0.Texts) div Max(1, Paints),
      Layouts, (CSSStats.LayoutMs - S0.LayoutMs) / Max(1, Layouts)]));
    if Paints > 0 then
      Lines.Add(Format('%-16s per paint: bitmaps %5.1f ms, texts %5.1f ms, %d clips %4.1f ms, resized bitmaps %.0f%% of window', ['',
        (CSSStats.BitmapMs - S0.BitmapMs) / Paints, (CSSStats.TextMs - S0.TextMs) / Paints,
        (CSSStats.Clips - S0.Clips) div Paints, (CSSStats.ClipMs - S0.ClipMs) / Paints,
        (CSSStats.StretchPixels - S0.StretchPixels) / Paints / Max(1, FShape.Width * FShape.Height) * 100]));
  end;
  procedure Flush;
  begin
    FShape.Update;
    Application.ProcessMessages;
  end;
begin
  if Assigned(FModal) then CloseTask;
  Lines := TStringList.Create;
  try
    Lines.Add(Format('Flowboard benchmark: %s, FPC %s, LCL %s, window %dx%d, PPI %d, pixel ratio %.2f, %d nodes',
      [{$I %FPCTARGETOS%}, {$I %FPCVERSION%}, LCLPlatformDisplayNames[WidgetSet.LCLPlatform], FShape.Width, FShape.Height,
      Screen.PixelsPerInch, FShape.Body.PixelRatio, FShape.Body.CountNodes(FShape.Body.FirstChild)]));
    Start;
    for I := 1 to 20 do FShape.Body.LayoutTo(0, 0, FShape.Width, FShape.Height);
    Report('layout only', 20);
    Start;
    for I := 1 to 10 do begin
      FShape.Invalidate;
      Flush;
    end;
    Report('full repaint', 10);
    {$ifdef windows}
    CSSFastBlend := False;               // drawing of bitmaps by LCL (for comparison)
    Start;
    for I := 1 to 10 do begin
      FShape.Invalidate;
      Flush;
    end;
    Report('repaint (LCL)', 10);
    CSSFastBlend := True;
    {$endif}
    Start;
    for I := 1 to 10 do begin
      FShape.Changed;
      Flush;
    end;
    Report('layout+repaint', 10);
    Start;
    for I := 1 to 60 do begin
      TShapeAccess(FShape).MouseMove([], 320 + (I * 97) mod (FShape.Width - 340), 160 + (I * 53) mod (FShape.Height - 200));
      Flush;
    end;
    Report('hover', 60);
    // detail dialog: open and change priority (properties are built again)
    Start;
    OpenTask(TTask(FTasks[0]));
    Report('open: build', 1);
    Lines.Add(Format('  (native controls %.1f ms, the rest is HTML, styles and layout)', [FControlsMs]));
    Start;
    Flush;
    Report('open: paint', 1);
    // second opening: bitmaps of dialog (shadow, corners, icons) are already cached
    CloseTask;
    Flush;
    Start;
    OpenTask(TTask(FTasks[0]));
    Flush;
    Report('open again', 1);
    Start;
    for I := 0 to 5 do begin
      FModalTask.Priority := I mod 3;
      BuildProps;
      Flush;
    end;
    Report('dialog click', 6);
    FModalTask.Priority := TTask(FTasks[0]).Priority;
    CloseTask;
    Flush;
    // drag first card of second column to the right (only nodes are moved, tasks are not changed)
    Card := FindByAttr(FindByAttr(FBoard.GetNext(FBoard.FirstChild), 'data-list'), 'data-task');
    if Assigned(Card) then begin
      P := Card.LayoutToScreen(PointF(Card.CompSize.MarginRect.Left + 40, Card.CompSize.MarginRect.Top + 20));
      X := Round(P.x);
      Y := Round(P.y);
      FDownCard := Card;
      FDownPos := Point(X, Y);
      Start;
      StartDrag(X, Y);
      for I := 1 to 40 do begin
        MoveDrag(X + I * 10, Y + (I mod 20) * 12);
        Flush;
      end;
      Report('drag', 40);
      FreeAndNil(FGhost);
      FDragging := False;
      FShape.HoverEnabled := True;
      FDownCard := nil;
    end;
    BuildToolbar;
    BuildBoard;
    Flush;
    Clipboard.AsText := Lines.Text;
    ShowMessage(Lines.Text + LineEnding + '(copied to clipboard)');
  finally
    Lines.Free;
  end;
end;

{ drag and drop }

procedure TKanbanForm.ShapeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  N: THtmlNode;
begin
  if FDragging then EndDrag;               // previous drag without mouse up
  FDragged := False;
  FDownCard := nil;
  if FRebuildPending then BuildBoardAsync(0);   // before nodes are found under mouse
  if (Button <> mbLeft) or Assigned(FModal) then Exit;
  N := FShape.Body.NodeAtPosition(Point(X, Y));
  if Assigned(N) and (N.Data is TTask) then begin
    FDownCard := N;
    FDownPos := Point(X, Y);
  end;
end;

procedure TKanbanForm.ShapeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDownCard = nil then Exit;
  if not (ssLeft in Shift) then begin     // button released outside (move without button): card is dropped
    if FDragging then EndDrag;
    FDownCard := nil;
    Exit;
  end;
  if not FDragging and (Max(Abs(X - FDownPos.X), Abs(Y - FDownPos.Y)) > 5) then StartDrag(X, Y);
  if FDragging then MoveDrag(X, Y);
end;

procedure TKanbanForm.ShapeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if FDragging then EndDrag;
  FDownCard := nil;
end;

(*
  Card is lifted: ghost (copy of card, rotated with big shadow) follows mouse, card stays in list as placeholder
*)
procedure TKanbanForm.StartDrag(X, Y: Integer);
const
  PAD = 36;                  // space around card for rotation and shadow
var
  P: TPointF;
  K: Single;
  R: TRect;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    FDragging := True;
    FDragged := True;
    FShape.HoverEnabled := False;            // cards under the dragged card don't react
    R := FDownCard.CompSize.MarginRect;
    P := FDownCard.LayoutToScreen(PointF(R.Left, R.Top));
    FGrab := Point(FDownPos.X - Round(P.x) + PAD, FDownPos.Y - Round(P.y) + PAD);
    K := Max(0.1, FShape.Body.PixelRatio);
    // ghost is a transparent TCSSShape above board: moving it repaints only the area under it
    FGhost := TCSSShape.Create(Self);
    FGhost.Enabled := False;                 // mouse stays with board
    FGhostSize := Point(R.Width + 2 * PAD, R.Height + 2 * PAD);
    FGhost.SetBounds(FShape.Left + X - FGrab.X, FShape.Top + Y - FGrab.Y, FGhostSize.X, FGhostSize.Y);
    FGhost.Body.SetClass(Format('p-[%dpx]', [Round(PAD / K)]));
    FGhost.Body.AppendHTML('<div class="rotate-2">' + CardHTML(TTask(FDownCard.Data)) + '</div>');
    FGhost.Body.FirstChild.FirstChild.SetClass(CARD_CLASS + ' shadow-2xl ring-1 ring-indigo-500/30');
    FGhost.Parent := Self;
    // card becomes placeholder with the same height (board is built again after drop)
    FDownCard.InlineStyle := Format('height: %dpx', [Round(FDownCard.CompSize.MarginRect.Height / K)]);
    FDownCard.Clear;
    FDownCard.SetClass('shrink-0 rounded-xl border-2 border-dashed border-indigo-300 dark:border-indigo-500/40 bg-indigo-50/60 dark:bg-indigo-500/5');
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.MoveDrag(X, Y: Integer);
var
  N, List, Ref: THtmlNode;
  R: TRect;
  P: TPointF;
  ScreenR: TRect;
begin
  FGhost.SetBounds(FShape.Left + X - FGrab.X, FShape.Top + Y - FGrab.Y, FGhostSize.X, FGhostSize.Y);
  // list under mouse (only horizontal position matters), card is inserted before first card below mouse
  List := nil;
  N := FBoard.FirstChild;
  while Assigned(N) do begin
    R := N.CompSize.MarginRect;
    P := N.LayoutToScreen(PointF(R.Left, R.Top));
    if (X >= P.x) and (X < P.x + R.Width) then begin
      List := FindByAttr(N, 'data-list');
      Break;
    end;
    N := FBoard.GetNext(N);
  end;
  if List = nil then Exit;
  Ref := List.FirstChild;
  while Assigned(Ref) do begin
    if not (Ref.Data is TTask) then Break;             // add button is after cards
    if (Ref <> FDownCard) and not Ref.ClassList.Contains('hidden') then begin
      R := Ref.CompSize.MarginRect;
      P := Ref.LayoutToScreen(PointF(R.Left, R.Top));
      ScreenR := Rect(Round(P.x), Round(P.y), Round(P.x) + R.Width, Round(P.y) + R.Height);
      if Y < (ScreenR.Top + ScreenR.Bottom) div 2 then Break;
    end;
    Ref := List.GetNext(Ref);
  end;
  // move placeholder only when its place changes
  if (FDownCard.ParentNode <> List) or (List.GetNext(FDownCard) <> Ref) then begin
    if Ref = FDownCard then Exit;
    List.InsertBefore(FDownCard, Ref);
    UpdateCounts;
    FShape.Changed;
  end;
end;

(*
  Card is dropped: tasks get columns and order of cards in lists
*)
procedure TKanbanForm.EndDrag;
var
  Task: TTask;
  Col, List, N: THtmlNode;
  Order: TList;
  I: Integer;
begin
  FDragging := False;
  FShape.HoverEnabled := True;
  FreeAndNil(FGhost);
  if FDownCard = nil then Exit;
  Task := TTask(FDownCard.Data);
  Task.Column := StrToIntDef(FDownCard.ParentNode.Attributes['data-list'], Task.Column);
  Order := TList.Create;
  try
    Col := FBoard.FirstChild;
    while Assigned(Col) do begin
      List := FindByAttr(Col, 'data-list');
      if Assigned(List) then begin
        N := List.FirstChild;
        while Assigned(N) do begin
          if N.Data is TTask then Order.Add(N.Data);
          N := List.GetNext(N);
        end;
      end;
      Col := FBoard.GetNext(Col);
    end;
    FTasks.OwnsObjects := False;
    FTasks.Clear;
    for I := 0 to Order.Count - 1 do FTasks.Add(TObject(Order[I]));
    FTasks.OwnsObjects := True;
  finally
    Order.Free;
  end;
  SaveTasks;
  // board is built again later (nodes of this mouse event must stay valid until click handling ends)
  FRebuildPending := True;
  Application.QueueAsyncCall(@BuildBoardAsync, 0);
end;

{ detail dialog }

procedure TKanbanForm.NewTask(ACol: Integer);
var
  T: TTask;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    T := TTask.Create;
    T.Title := 'New task';
    T.Column := ACol;
    T.Priority := 1;
    T.Assignee := ME;
    FTasks.Add(T);
    SaveTasks;
    BuildToolbar;
    BuildBoard;
    OpenTask(T);
    if Assigned(FTitleEdit) then FTitleEdit.SelectAll;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.OpenTask(T: TTask);
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    if Assigned(FModal) then CloseTask;
    FModalTask := T;
    FModalColumn := T.Column;
    FSearch.Visible := False;              // native control is not dimmed by backdrop
    FShape.Body.AppendHTML(
      '<div id="modal" class="absolute inset-0 z-40 flex items-center justify-center bg-slate-950/50" data-action="close">' +
      '<div id="panel" class="w-[600px] flex flex-col gap-5 p-7 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 ' +
      'dark:border-slate-800 shadow-2xl">' +
      '<div class="flex items-center gap-2 text-xs text-slate-400">' + SvgIcon(icSquareKanban, 'size-4') +
      '<div class="flex-1">Product launch</div>' +
      '<div class="' + ICON_BUTTON + ' hover:text-rose-600 dark:hover:text-rose-400" data-action="delete">' + SvgIcon(icTrash2, 'size-[18px]') + '</div>' +
      '<div class="' + ICON_BUTTON + '" data-action="close">' + SvgIcon(icX, 'size-[18px]') + '</div></div>' +
      '<div class="h-9" id="title"></div>' +
      '<div class="flex flex-col gap-2"><div class="flex items-center gap-2 text-xs font-semibold text-slate-500 dark:text-slate-400">' +
      SvgIcon(icAlignLeft, 'size-4') + 'Description</div>' +
      '<div class="h-24 px-3 py-2 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">' +
      '<div class="h-full" id="desc"></div></div></div>' +
      '<div id="props" class="flex flex-col gap-5"></div>' +
      '<div class="flex justify-end"><div class="h-10 flex items-center px-5 rounded-xl bg-indigo-600 hover:bg-indigo-500 ' +
      'text-white text-sm font-semibold shadow-md shadow-indigo-500/25 transition-colors cursor-pointer" data-action="close">Done</div></div>' +
      '</div></div>');
    FModal := FShape.Body.GetElementById('modal');
    FPanel := FShape.Body.GetElementById('panel');
    FProps := FShape.Body.GetElementById('props');
    Bind(FModal);
    FPanel.OnClick := @PanelClick;
    FControlsMs := CSSTimeMs;
    FTitleEdit := TEdit.Create(Self);
    FTitleEdit.BorderStyle := bsNone;
    FTitleEdit.Font.Size := 16;
    FTitleEdit.Font.Style := [fsBold];
    FTitleEdit.Text := T.Title;
    FTitleEdit.OnChange := @TitleChange;
    FTitleEdit.Parent := Self;
    FDescMemo := TMemo.Create(Self);
    FDescMemo.BorderStyle := bsNone;
    FDescMemo.WordWrap := True;
    FDescMemo.Text := T.Description;
    FDescMemo.OnChange := @DescChange;
    FDescMemo.Parent := Self;
    FShape.Body.GetElementById('title').SetAlignControl(FTitleEdit);
    FShape.Body.GetElementById('desc').SetAlignControl(FDescMemo);
    FControlsMs := CSSTimeMs - FControlsMs;
    UpdateControlColors;
    BuildProps;
    // dialog is shown at once (no animation: whole window would be painted again in every frame)
    if FTitleEdit.CanFocus then FTitleEdit.SetFocus;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.BuildProps;
var
  S: String;
  I: Integer;
  T: TTask;
  function PropPill(AOn: Boolean; const AAction: String; AValue: Integer; const AContent: String): String;
  var
    C: String;
  begin
    if AOn then C := PILL + PILL_ON else C := PILL + PILL_OFF;
    Result := Format('<div class="%s" data-action="%s" data-v="%d">%s</div>', [C, AAction, AValue, AContent]);
  end;
  function Row(AIcon: TIconName; const AName, AContent: String): String;
  begin
    Result := '<div class="flex items-center gap-4"><div class="w-28 shrink-0 flex items-center gap-2 text-xs font-semibold ' +
      'text-slate-500 dark:text-slate-400">' + SvgIcon(AIcon, 'size-4') + AName + '</div>' +
      '<div class="flex flex-wrap items-center gap-2">' + AContent + '</div></div>';
  end;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    T := FModalTask;
    if (T = nil) or (FProps = nil) then Exit;
    FProps.Clear;
    S := '';
    for I := 0 to High(COLUMNS) do
      S := S + PropPill(T.Column = I, 'status', I, '<div class="size-2 rounded-full ' + COLUMNS[I].Dot + '"></div>' + COLUMNS[I].Name);
    FProps.AppendHTML(Row(icSquareKanban, 'Status', S));
    S := '';
    for I := 0 to 2 do
      S := S + PropPill(T.Priority = I, 'priority', I, PRIORITIES[I]);
    FProps.AppendHTML(Row(icFlag, 'Priority', S));
    S := '';
    for I := 0 to High(PEOPLE) do
      if T.Assignee = I then
        S := S + Format('<div class="rounded-full ring-2 ring-indigo-500 ring-offset-2 cursor-pointer" data-action="assignee" data-v="%d">%s</div>',
          [I, Avatar(I, 'size-8 text-[11px]')])
      else
        S := S + Format('<div class="rounded-full opacity-50 hover:opacity-100 transition-opacity cursor-pointer" data-action="assignee" data-v="%d">%s</div>',
          [I, Avatar(I, 'size-8 text-[11px]')]);
    FProps.AppendHTML(Row(icUserRound, 'Assignee', S));
    S := '';
    for I := 0 to High(LABELS) do
      S := S + PropPill(T.Labels and (1 shl I) <> 0, 'label', I, '<div class="size-2 rounded-full bg-' + LABELS[I].Color + '-500"></div>' +
        LABELS[I].Name);
    FProps.AppendHTML(Row(icTag, 'Labels', S));
    if Length(T.Checks) > 0 then begin
      S := Format('<div class="flex flex-col gap-2"><div class="flex items-center gap-2 text-xs font-semibold text-slate-500 ' +
        'dark:text-slate-400">%sChecklist<div class="flex-1"></div>%d/%d</div>', [SvgIcon(icListChecks, 'size-4'), T.DoneChecks, Length(T.Checks)]);
      for I := 0 to High(T.Checks) do
        if T.Checks[I].Done then
          S := S + Format('<div class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 ' +
            'cursor-pointer" data-action="check" data-v="%d">%s<div class="text-sm text-slate-400 line-through">%s</div></div>',
            [I, SvgIcon(icCircleCheckBig, 'size-[18px] text-emerald-500'), Esc(T.Checks[I].Text)])
        else
          S := S + Format('<div class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 ' +
            'cursor-pointer" data-action="check" data-v="%d">%s<div class="text-sm">%s</div></div>',
            [I, SvgIcon(icCircle, 'size-[18px] text-slate-300 dark:text-slate-600'), Esc(T.Checks[I].Text)]);
      FProps.AppendHTML(S + '</div>');
    end;
    Bind(FProps);
    FShape.Changed;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.CloseTask;
begin
  CSSBeginUpdate;     // one layout for all changes
  try
    if Assigned(FModal) then begin
      FShape.Body.Delete(FModal);         // nodes first, then controls placed in them
      FModal := nil;
      FPanel := nil;
      FProps := nil;
    end;
    FreeAndNil(FTitleEdit);
    FreeAndNil(FDescMemo);
    FSearch.Visible := True;
    SaveTasks;
    BuildToolbar;
    // only columns with changed task are built again (old and new column)
    BuildColumn(FModalColumn);
    if Assigned(FModalTask) and (FModalTask.Column <> FModalColumn) then BuildColumn(FModalTask.Column);
    FModalTask := nil;
  finally
    CSSEndUpdate;
  end;
end;

procedure TKanbanForm.TitleChange(Sender: TObject);
begin
  if Assigned(FModalTask) then FModalTask.Title := FTitleEdit.Text;
end;

procedure TKanbanForm.DescChange(Sender: TObject);
begin
  if Assigned(FModalTask) then FModalTask.Description := FDescMemo.Text;
end;

end.
