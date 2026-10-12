unit agentmain;

(*
  Desktop app of an AI assistant built with csscontrols: sidebar with threads, a prompt composer (native TMemo placed
  in a node) with suggestions and a conversation where the answer is written word by word. Answers are prepared
  texts, nothing is sent anywhere. Background is a vertical gradient (a stretched strip, fast to paint).
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Contnrs, Controls, Forms, Graphics, StdCtrls, ExtCtrls, Dialogs, LCLType, Clipbrd,
  cssbase, CSSCtrls, csshtml, agenticons;

type
  TBlock = record
    Kind: Char;                // p paragraph, h heading, l list item, c code (first line is language)
    Text: String;
  end;
  TBlocks = array of TBlock;

  { TChatMessage }

  TChatMessage = class
    FromUser: Boolean;
    Text: String;              // message of user
    Files: String;             // names of attached files (user), one per line
    Blocks: TBlocks;           // answer of agent
  end;

  { TChat }

  TChat = class
    Title, Preview: String;
    Group: Integer;            // index in GROUPS (today, previous 7 days)
    Messages: TObjectList;
    constructor Create(const ATitle, APreview: String);
    destructor Destroy; override;
  end;

  { TAgentForm }

  TAgentForm = class(TForm)
  private
    FShape: TCSSShape;
    FChats: TObjectList;
    FChat: TChat;              // open chat, nil = start page
    FTab, FSection, FModel: Integer;
    FWebSearch, FCanSend, FInputShown, FSearchShown, FEatReturn: Boolean;
    FFiles: TStringList;       // files attached to next message
    FTabs, FNav, FRecents, FSearchBox, FHomeTop, FHomeBottom, FList, FMessages, FComposerRow,
      FFilesBox, FHint, FInput, FTools: THtmlNode;
    FMemo: TMemo;
    FSearch: TEdit;
    FMenuOpen, FSnapshot: Boolean;   // model menu, memo text is painted by renderer while menu is open
    // answer written word by word
    FTimer: TTimer;
    FAnswer: TChatMessage;
    FAnswerBox, FTarget, FThinking: THtmlNode;
    FBlock, FPos: Integer;
    FThinkUntil: QWord;
    function Px(AValue: Integer): Integer;
    procedure SeedChats;
    procedure Bind(ANode: THtmlNode);
    procedure BuildSidebar(AParent: THtmlNode);
    procedure BuildMain(AParent: THtmlNode);
    procedure BuildTabs;
    procedure SelectTab(AIndex: Integer);
    procedure SetMenu(AOpen: Boolean);
    procedure ShapeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BuildNav;
    procedure BuildRecents;
    procedure BuildFiles;
    procedure BuildTools;
    procedure ShowView(AChat: Boolean);
    procedure ShowHome;
    procedure OpenChat(AChat: TChat);
    procedure BuildMessages(ASkipLast: Boolean);
    procedure ShowInput;
    procedure Send;
    procedure StartAnswer(AMessage: TChatMessage);
    procedure StopAnswer;
    procedure FinishAnswer;
    procedure ScrollToEnd;
    procedure AnswerTick(Sender: TObject);
    procedure ActionClick(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure MemoExit(Sender: TObject);
    procedure MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MemoKeyPress(Sender: TObject; var Key: Char);
    procedure SearchChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
  end;

var
  AgentForm: TAgentForm;

implementation

type
  TQuickStart = record
    Icon: TIconName;
    Title, Prompt: String;
  end;

const
  USER_NAME = 'Olivia';
  USER_PLAN = 'Pro plan';
  APP_NAME = 'Assistant';
  MODELS: array[0..2] of String = ('Deep 2', 'Quick 2', 'Lite 1');
  MODEL_INFO: array[0..2] of String = ('Careful reasoning for hard problems', 'Balanced speed for everyday work',
    'Shortest answers, lowest cost');
  TAB_WIDTH = 104;           // tabs have the same width, so only translate of indicator is animated
  TABS: array[0..2] of String = ('Chat', 'Research', 'Build');
  HINTS: array[0..2] of String = ('Ask anything...', 'What should I look into for you?',
    'Describe the app, script or page you want...');
  GROUPS: array[0..1] of String = ('TODAY', 'PREVIOUS 7 DAYS');
  SECTIONS: array[0..3] of String = ('Threads', 'Spaces', 'Automations', 'Library');
  SECTION_ICONS: array[0..3] of TIconName = (icMessageSquare, icFolderOpen, icZap, icBookOpen);
  QUICK: array[0..3] of TQuickStart = (
    (Icon: icCodeXml; Title: 'Write code'; Prompt: 'Write a TypeScript script that loads users from an API and groups them by e-mail domain.'),
    (Icon: icFileText; Title: 'Summarize a file'; Prompt: 'Summarize the attached document and list the decisions it asks for.'),
    (Icon: icLightbulb; Title: 'Brainstorm'; Prompt: 'Brainstorm ten small tools that would save a team an hour every week.'),
    (Icon: icMapPin; Title: 'Plan a trip'; Prompt: 'Plan a relaxed three day trip to Lisbon with good food and short walks.'));

  ITEM = 'flex items-center gap-3 h-9 px-3 rounded-lg text-sm font-medium cursor-pointer transition-colors ';
  ITEM_ON = 'bg-[#e9ebf2] text-slate-900';
  ITEM_OFF = 'text-slate-700 hover:bg-[#eef0f5]';
  TOOL = 'size-9 flex items-center justify-center rounded-lg cursor-pointer transition-colors ';
  LIST_CLASS = 'flex-1 min-h-0 flex flex-col items-center overflow-y-auto';
  HOME_TOP_CLASS = 'flex-1 min-h-0 flex flex-col items-center justify-end gap-3 px-8 pb-8';
  HOME_BOTTOM_CLASS = 'flex-1 min-h-0 flex flex-col items-center px-8 pt-6';
  HINT_CLASS = 'text-base text-slate-400';
  TEXT_CLASS = 'text-[15px] text-slate-700';

function Esc(const S: String): String;
begin
  Result := StringReplace(StringReplace(StringReplace(S, '&', '&amp;', [rfReplaceAll]), '<', '&lt;', [rfReplaceAll]),
    '>', '&gt;', [rfReplaceAll]);
end;

(*
  Dark tooltip shown on hover (pure CSS like in csscontrols demo): AControl is wrapped in a group, tooltip is
  its transparent absolute child shown by group-hover with fade
*)
function Tooltip(const AControl, AText: String; ABelow: Boolean = False): String;
var
  Place, Arrow: String;
begin
  if ABelow then begin
    Place := 'top-full left-1/2 -translate-x-1/2 mt-2';
    Arrow := 'bottom-full left-1/2 -translate-x-1/2 -mb-1';
  end else begin
    Place := 'bottom-full left-1/2 -translate-x-1/2 mb-2';
    Arrow := 'top-full left-1/2 -translate-x-1/2 -mt-1';
  end;
  Result := '<div class="group relative">' + AControl + '<div class="absolute ' + Place + ' z-10 opacity-0 ' +
    'group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap px-2.5 py-1.5 rounded-md ' +
    'bg-slate-900 text-white text-xs font-medium shadow-lg">' + AText + '<div class="absolute ' + Arrow +
    ' size-2 rotate-45 bg-slate-900"></div></div></div>';
end;

function FirstLine(const S: String): String;
var
  I: Integer;
begin
  Result := Trim(S);
  I := Pos(#10, Result);
  if I > 0 then Result := Trim(Copy(Result, 1, I - 1));
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

function LastChild(ANode: THtmlNode): THtmlNode;
var
  C: THtmlNode;
begin
  Result := nil;
  C := ANode.FirstChild;
  while Assigned(C) do begin
    Result := C;
    C := ANode.GetNext(C);
  end;
end;

{ answers }

procedure AddBlock(var ABlocks: TBlocks; AKind: Char; const AText: String);
begin
  SetLength(ABlocks, Length(ABlocks) + 1);
  ABlocks[High(ABlocks)].Kind := AKind;
  ABlocks[High(ABlocks)].Text := AText;
end;

function CodeLines(const AText: String): TStringArray;
begin
  Result := AText.Split([#10]);
  Result := Copy(Result, 1, Length(Result) - 1);     // without language
end;

function CodeLanguage(const AText: String): String;
begin
  Result := AText.Split([#10])[0];
end;

function MakeAnswer(const APrompt: String; AFiles: TStrings): TBlocks;
var
  P: String;
  procedure Add(AKind: Char; const AText: String);
  begin
    AddBlock(Result, AKind, AText);
  end;
  function Has(const AWords: array of String): Boolean;
  var
    W: String;
  begin
    for W in AWords do
      if Pos(W, P) > 0 then Exit(True);
    Result := False;
  end;
begin
  Result := nil;
  P := LowerCase(APrompt);
  if Has(['script', 'code', 'typescript', 'function', 'program']) then begin
    Add('p', 'Here is a small TypeScript script that fetches JSON from an API, groups the records and prints a short ' +
      'report. It uses only the built-in fetch, so it runs in Node 18+ or Deno without extra packages.');
    Add('c', 'typescript'#10 +
      'type User = { id: number; name: string; email: string };'#10 +
      ''#10 +
      'async function fetchUsers(url: string): Promise<User[]> {'#10 +
      '  const response = await fetch(url);'#10 +
      '  if (!response.ok) throw new Error(`HTTP ${response.status}`);'#10 +
      '  return (await response.json()) as User[];'#10 +
      '}'#10 +
      ''#10 +
      'function byDomain(users: User[]) {'#10 +
      '  const domains = new Map<string, number>();'#10 +
      '  for (const user of users) {'#10 +
      '    const domain = user.email.split("@")[1];'#10 +
      '    domains.set(domain, (domains.get(domain) ?? 0) + 1);'#10 +
      '  }'#10 +
      '  return [...domains].sort((a, b) => b[1] - a[1]);'#10 +
      '}'#10 +
      ''#10 +
      'const users = await fetchUsers("https://api.example.com/users");'#10 +
      'console.table(byDomain(users));');
    Add('h', 'How it works');
    Add('l', 'fetchUsers checks the HTTP status before parsing, so failed requests are not silently ignored.');
    Add('l', 'byDomain groups users by the domain of their e-mail and sorts the groups by size.');
    Add('l', 'console.table prints the result as a readable table in the terminal.');
    Add('p', 'Do you want me to add retries, pagination or write the result to a CSV file?');
  end else if Has(['document', 'summar', 'pdf']) then begin
    if Assigned(AFiles) and (AFiles.Count > 0) then
      Add('p', 'I went through ' + AFiles[0] + '. Here is a summary of the main points and what they mean for you.')
    else
      Add('p', 'Attach the document with the paperclip below and I will summarize it. Until then, this is the ' +
        'structure I use for every summary, so you know what to expect.');
    Add('h', 'Summary');
    Add('l', 'Purpose: what the document wants to achieve and who it is written for.');
    Add('l', 'Key findings: the three to five statements that carry the most weight, with page references.');
    Add('l', 'Numbers: figures worth remembering, compared with the previous period where possible.');
    Add('h', 'Insights');
    Add('l', 'Risks and open questions the document does not answer.');
    Add('l', 'Decisions it asks for, with a suggested owner and deadline.');
    Add('p', 'Tell me if you prefer a one paragraph executive summary instead.');
  end else if Has(['brainstorm', 'ideas', 'idea']) then begin
    Add('p', 'Here are ten small tools, each solving one narrow problem well. Narrow tools are easier to build, ' +
      'explain and adopt than general assistants.');
    Add('l', 'Meeting memory: remembers decisions from calls and reminds people when they are about to contradict them.');
    Add('l', 'Inbox triage for support teams that drafts answers from the product documentation.');
    Add('l', 'Contract diff: compares two versions of a contract and explains the changes in plain language.');
    Add('l', 'Release notes writer that turns merged pull requests into notes for customers.');
    Add('l', 'Onboarding buddy that answers new employees from the company wiki and points to the right person.');
    Add('l', 'Spreadsheet doctor: finds broken formulas, duplicates and outliers and suggests fixes.');
    Add('l', 'Sales call coach with feedback on talk ratio, questions and next steps.');
    Add('l', 'Accessibility checker for design files that suggests contrast and size fixes before handoff.');
    Add('l', 'Grant finder that matches research projects with open calls and drafts the first application.');
    Add('l', 'Personal finance explainer that reads bank exports and answers questions about spending.');
    Add('p', 'Pick two or three and I will outline the target users, pricing and a first version for each.');
  end else if Has(['trip', 'travel', 'lisbon', 'weekend']) then begin
    Add('p', 'Here is a relaxed plan for three days in Lisbon. Mornings are for sights, afternoons are short and ' +
      'evenings are for food. Use trams and taxis for the hills.');
    Add('h', 'Day 1: Alfama and the castle');
    Add('l', 'Tram 28 up to the castle in the morning, before the crowds.');
    Add('l', 'Walk down through Alfama, it is downhill all the way.');
    Add('l', 'Dinner with fado in a small family restaurant.');
    Add('h', 'Day 2: Belem');
    Add('l', 'Jeronimos Monastery and the tower, with pastries from the famous bakery nearby.');
    Add('l', 'Afternoon at the riverside, the promenade is flat and long.');
    Add('h', 'Day 3: Chiado and the view points');
    Add('l', 'Coffee in Chiado, then the Santa Justa lift for the view.');
    Add('l', 'Sunset at a miradouro and seafood for the last dinner.');
    Add('p', 'Do you want hotel suggestions close to the tram line?');
  end else if Has(['research', 'quantum', 'overview']) then begin
    Add('p', 'Quantum computing uses quantum mechanics to process information in ways classical computers cannot. ' +
      'Here is an overview of the concepts, the applications and where the field stands.');
    Add('h', 'Key concepts');
    Add('l', 'Qubits can be in a superposition of 0 and 1, so a register of n qubits describes 2^n amplitudes at once.');
    Add('l', 'Entanglement links qubits, so measuring one tells you something about the others.');
    Add('l', 'Interference lets algorithms amplify right answers and cancel wrong ones.');
    Add('h', 'Applications');
    Add('l', 'Simulation of molecules and materials for chemistry, batteries and drug discovery.');
    Add('l', 'Optimization problems in logistics and finance, although the advantage is not proven yet.');
    Add('l', 'Cryptography: Shor''s algorithm would break RSA, which is why post-quantum standards exist.');
    Add('h', 'Where it stands');
    Add('p', 'Current machines have hundreds to a few thousand noisy qubits. Error correction is the main challenge: ' +
      'useful fault tolerant computers need many physical qubits for each logical one.');
  end else begin
    Add('p', 'Good question. Here is a structured first take on "' + FirstLine(APrompt) + '".');
    Add('h', 'Approach');
    Add('l', 'Clarify the goal and how you will know that the result is good enough.');
    Add('l', 'Collect what already exists, so we do not start from a blank page.');
    Add('l', 'Make a small first version, test it with real users and improve it in short steps.');
    Add('h', 'Next steps');
    Add('l', 'Share any documents or examples that I should take into account.');
    Add('l', 'Tell me the constraints: time, budget and the tools you already use.');
    Add('p', 'Tell me more about your goal and I will go deeper.');
  end;
end;

function BlocksText(const ABlocks: TBlocks): String;
var
  B: TBlock;
  L: String;
begin
  Result := '';
  for B in ABlocks do begin
    case B.Kind of
      'l': Result := Result + '- ' + B.Text + LineEnding;
      'c': for L in CodeLines(B.Text) do Result := Result + L + LineEnding;
      else Result := Result + B.Text + LineEnding;
    end;
    Result := Result + LineEnding;
  end;
  Result := Trim(Result);
end;

function CodeLineHTML(const ALine: String): String;
var
  N: Integer;
begin
  if Trim(ALine) = '' then Exit('<div class="h-4"></div>');
  N := Length(ALine) - Length(TrimLeft(ALine));    // indentation (spaces of markup are collapsed)
  Result := '<div class="whitespace-nowrap" style="padding-left: ' + IntToStr(N * 8) + 'px">' +
    Esc(TrimLeft(ALine)) + '</div>';
end;

(*
  Block of answer, AFull = False: text is empty (written word by word), its node has attribute data-t
*)
function BlockHTML(const ABlock: TBlock; AFull: Boolean): String;
var
  S, L: String;
begin
  if AFull then S := Esc(ABlock.Text) else S := '';
  case ABlock.Kind of
    'h': Result := '<div class="pt-1 text-[15px] font-semibold text-slate-900" data-t="1">' + S + '</div>';
    'l': Result := '<div class="flex gap-3 ' + TEXT_CLASS + '"><div class="size-1.5 mt-2 shrink-0 rounded-full ' +
      'bg-violet-400"></div><div class="flex-1 min-w-0" data-t="1">' + S + '</div></div>';
    'c': begin
      Result := '<div class="flex flex-col rounded-xl bg-[#0f172a] overflow-hidden">' +
        '<div class="h-9 flex items-center justify-between px-4 bg-[#1e293b] text-xs text-slate-400"><div>' +
        Esc(CodeLanguage(ABlock.Text)) + '</div>' + '<div class="flex items-center gap-1.5">' +
        SvgIcon(icCopy, 'size-3.5') + 'Copy</div></div>' +
        '<div class="flex flex-col gap-0.5 p-4 font-mono text-[13px] text-slate-100 overflow-x-auto" data-t="1">';
      if AFull then
        for L in CodeLines(ABlock.Text) do Result := Result + CodeLineHTML(L);
      Result := Result + '</div></div>';
    end;
    else Result := '<div class="' + TEXT_CLASS + '" data-t="1">' + S + '</div>';
  end;
end;

function AgentAvatar: String;
begin
  Result := '<div class="size-8 shrink-0 flex items-center justify-center rounded-lg bg-gradient-to-br ' +
    'from-violet-500 to-sky-400 text-white shadow-sm shadow-violet-500/30">' + SvgIcon(icSparkles, 'size-4') + '</div>';
end;

function FileChip(const AName: String; AIndex: Integer): String;
begin
  Result := '<div class="h-8 flex items-center gap-2 pl-2.5 pr-2 rounded-lg bg-[#eef0f6] text-[13px] text-slate-700">' +
    SvgIcon(icFileText, 'size-4 text-violet-500') + '<div>' + Esc(AName) + '</div>';
  if AIndex >= 0 then
    Result := Result + '<div class="size-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 ' +
      'hover:text-slate-700 cursor-pointer" data-action="unattach" data-v="' + IntToStr(AIndex) + '">' +
      SvgIcon(icX, 'size-3.5') + '</div>';
  Result := Result + '</div>';
end;

{ TChat }

constructor TChat.Create(const ATitle, APreview: String);
begin
  Title := ATitle;
  Preview := APreview;
  Messages := TObjectList.Create(True);
end;

destructor TChat.Destroy;
begin
  Messages.Free;
  inherited Destroy;
end;

{ TAgentForm }

constructor TAgentForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Caption := APP_NAME;
  Width := 1360;
  Height := 880;
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  FChats := TObjectList.Create(True);
  FFiles := TStringList.Create;
  SeedChats;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 40;
  FTimer.OnTimer := @AnswerTick;

  FShape := TCSSShape.Create(Self);
  FShape.Parent := Self;
  FShape.Align := alClient;
  FShape.OnMouseDown := @ShapeMouseDown;
  CSSBeginUpdate;
  try
    FShape.Body.SetClass('h-full flex bg-[#f7f8fb] text-slate-900');
    BuildSidebar(FShape.Body);
    BuildMain(FShape.Body);
  finally
    CSSEndUpdate;          // shape is laid out once here
  end;
end;

destructor TAgentForm.Destroy;
begin
  FChats.Free;
  FFiles.Free;
  inherited Destroy;
end;

// CSS px in pixels of native controls (CSS px are scaled by DPI on Windows and Linux, macOS uses points)
function TAgentForm.Px(AValue: Integer): Integer;
begin
  Result := AValue;
  {$ifndef darwin}
  if Screen.PixelsPerInch > 96 then Result := Round(AValue * Screen.PixelsPerInch / 96);
  {$endif}
end;

procedure TAgentForm.SeedChats;
  procedure Chat(AGroup: Integer; const ATitle, APreview, APrompt: String; const ABlocks: TBlocks);
  var
    C: TChat;
    M: TChatMessage;
  begin
    C := TChat.Create(ATitle, APreview);
    C.Group := AGroup;
    M := TChatMessage.Create;
    M.FromUser := True;
    M.Text := APrompt;
    C.Messages.Add(M);
    M := TChatMessage.Create;
    M.Blocks := ABlocks;
    C.Messages.Add(M);
    FChats.Add(C);
  end;
var
  B: TBlocks;
begin
  B := nil;
  AddBlock(B, 'p', 'Revenue grew 12% compared with the previous quarter, mostly from the two largest customers. ' +
    'Costs stayed flat, so the margin improved by three points.');
  AddBlock(B, 'h', 'For the leadership meeting');
  AddBlock(B, 'l', 'Churn rose to 4.1%, small customers leave after the first year.');
  AddBlock(B, 'l', 'The new pricing is live for half of the customers, results come next quarter.');
  AddBlock(B, 'l', 'Hiring is behind plan: three of eight positions are filled.');
  AddBlock(B, 'p', 'The decision to ask for: a retention program for small customers, owner and budget.');
  Chat(0, 'Quarterly report summary', 'Revenue grew 12%, churn is the main risk',
    'Summarize the quarterly report for the leadership meeting.', B);

  B := nil;
  AddBlock(B, 'p', 'Here is a calm weekend: one area per day, short walks and long lunches.');
  AddBlock(B, 'l', 'Saturday: old town and the castle, tram up, walk down.');
  AddBlock(B, 'l', 'Sunday: riverside, museum in the morning and a picnic in the park.');
  AddBlock(B, 'p', 'Tell me your budget and I will add places to stay.');
  Chat(0, 'Lisbon weekend plan', 'Three relaxed days with food and views', 'Plan a relaxed weekend in Lisbon.', B);

  B := nil;
  AddBlock(B, 'p', 'Split the unit by responsibility: types and constants, parsing, and drawing. Other units keep ' +
    'using the old name through a small unit that only re-exports what they need.');
  AddBlock(B, 'c', 'pascal'#10 +
    'unit shapes;'#10 +
    ''#10 +
    'interface'#10 +
    ''#10 +
    'uses'#10 +
    '  shapetypes, shapeparser, shapepaint;'#10 +
    ''#10 +
    'type'#10 +
    '  TShape = shapetypes.TShape;'#10 +
    ''#10 +
    'function ParseShape(const AText: String): TShape;'#10 +
    ''#10 +
    'implementation'#10 +
    ''#10 +
    'function ParseShape(const AText: String): TShape;'#10 +
    'begin'#10 +
    '  Result := shapeparser.Parse(AText);'#10 +
    'end;'#10 +
    ''#10 +
    'end.');
  AddBlock(B, 'p', 'Move one part at a time and run the tests after each step, so a broken build points to one move.');
  Chat(1, 'Refactor a Pascal unit', 'Splitting a 2000 line unit into modules',
    'How should I split a 2000 line Pascal unit into smaller units?', B);

  B := nil;
  AddBlock(B, 'h', 'Subject');
  AddBlock(B, 'p', 'Welcome aboard, your workspace is ready');
  AddBlock(B, 'h', 'Body');
  AddBlock(B, 'p', 'Thanks for joining. Everything is set up, the only step left is to invite your team, it takes ' +
    'less than a minute.');
  AddBlock(B, 'l', 'One clear button: Invite your team.');
  AddBlock(B, 'l', 'A link to a two minute video for those who prefer to watch.');
  Chat(1, 'Welcome email for new users', 'Short, friendly and with one clear next step',
    'Write a welcome email for new users of our app.', B);

  B := nil;
  AddBlock(B, 'p', 'A vector database stores texts, images or products as lists of numbers (embeddings), where ' +
    'similar things get similar numbers.');
  AddBlock(B, 'h', 'How a search works');
  AddBlock(B, 'l', 'The question is turned into an embedding with the same model.');
  AddBlock(B, 'l', 'An index finds the nearest vectors without comparing all of them.');
  AddBlock(B, 'l', 'The closest items are returned, often to give an assistant the right context.');
  Chat(1, 'How do vector databases work', 'Embeddings, similarity search and indexes',
    'Explain how vector databases work.', B);
end;

(*
  Click handlers of nodes from markup (data-action)
*)
procedure TAgentForm.Bind(ANode: THtmlNode);
var
  C: THtmlNode;
begin
  if ANode.Attributes['data-action'] <> '' then ANode.OnClick := @ActionClick;
  C := ANode.FirstChild;
  while Assigned(C) do begin
    Bind(C);
    C := ANode.GetNext(C);
  end;
end;

procedure TAgentForm.BuildSidebar(AParent: THtmlNode);
  function Action(AIcon: TIconName; const AName, AAction, AIconClass: String): String;
  begin
    Result := '<div class="' + ITEM + ITEM_OFF + '"';
    if AAction <> '' then Result := Result + ' data-action="' + AAction + '"';
    Result := Result + '>' + SvgIcon(AIcon, 'size-[18px] ' + AIconClass, '1.75') + AName + '</div>';
  end;
var
  Side: THtmlNode;
begin
  Side := HTMLNode('relative z-10 w-72 shrink-0 flex flex-col gap-1 px-3 pt-4 pb-3 border-r border-[#e6e8ef]').AppendTo(AParent);
  Side.AppendHTML(
    '<div class="flex items-center gap-2.5 px-2 pb-3">' +
    '<div class="size-8 flex items-center justify-center rounded-lg bg-gradient-to-br from-violet-500 to-sky-400 ' +
    'text-white shadow-sm shadow-violet-500/30">' + SvgIcon(icSparkles, 'size-4') + '</div>' +
    '<div class="text-[15px] font-semibold">' + APP_NAME + '</div></div>' +
    '<div class="h-10 mb-2 flex items-center justify-center gap-2 rounded-lg bg-white border border-[#e3e6ee] shadow-sm ' +
    'text-sm font-medium text-slate-800 cursor-pointer transition-colors hover:border-violet-300 hover:text-violet-700" ' +
    'data-action="new">' + SvgIcon(icPlus, 'size-4') + 'New thread</div>' +
    Action(icSearch, 'Search', 'search', 'text-slate-500') +
    '<div id="searchbox" class="hidden h-9 flex items-center gap-2 mx-1 px-3 rounded-lg bg-white border ' +
    'border-[#e3e6ee] text-slate-400 focus-within:border-violet-300 focus-within:ring-4 focus-within:ring-violet-500/10">' +
    SvgIcon(icSearch, 'size-4 shrink-0') + '<div class="flex-1 h-6" id="search"></div></div>' +
    '<div id="nav" class="flex flex-col gap-0.5"></div>' +
    '<div id="recents" class="flex-1 min-h-0 flex flex-col gap-0.5 mt-3 overflow-y-auto"></div>' +
    '<div class="flex items-center gap-3 mx-1 pt-3 border-t border-[#e6e8ef]">' +
    '<div class="size-9 shrink-0 flex items-center justify-center rounded-full bg-gradient-to-br from-amber-400 ' +
    'to-rose-400 text-white text-sm font-semibold">' + USER_NAME[1] + '</div>' +
    '<div class="flex-1 min-w-0 flex flex-col"><div class="text-sm font-medium">' + USER_NAME + '</div>' +
    '<div class="text-xs text-slate-500">' + USER_PLAN + '</div></div>' +
    Tooltip('<div class="' + TOOL + 'text-slate-500 hover:bg-[#eef0f5] hover:text-slate-900">' + SvgIcon(icSettings, 'size-4') +
      '</div>', 'Settings') +
    '</div>');
  Bind(Side);
  FNav := Side.GetElementById('nav');
  FRecents := Side.GetElementById('recents');
  FSearchBox := Side.GetElementById('searchbox');
  FSearch := TEdit.Create(Self);
  FSearch.Parent := Self;
  FSearch.BorderStyle := bsNone;
  FSearch.Color := clWhite;
  FSearch.Font.Color := RGBToColor(15, 23, 42);
  FSearch.TextHint := 'Search threads...';
  FSearch.OnChange := @SearchChange;
  Side.GetElementById('search').SetAlignControl(FSearch);
  BuildNav;
  BuildRecents;
end;

procedure TAgentForm.BuildMain(AParent: THtmlNode);
var
  Main: THtmlNode;
  S: String;
  I: Integer;
begin
  Main := HTMLNode('flex-1 min-w-0 flex flex-col bg-gradient-to-b from-[#e9e7fb] via-[#f5f6fb] to-[#ddf1ec]').AppendTo(AParent);
  S := '';
  for I := 0 to High(QUICK) do
    S := S + '<div class="h-9 flex items-center gap-2 px-3.5 rounded-full bg-white border border-[#e3e6ee] text-sm ' +
      'text-slate-600 shadow-sm cursor-pointer transition hover:border-violet-300 hover:text-slate-900 hover:shadow-md ' +
      'hover:shadow-violet-500/10" data-action="quick" data-v="' + IntToStr(I) + '">' +
      SvgIcon(QUICK[I].Icon, 'size-4 text-violet-500') + QUICK[I].Title + '</div>';
  Main.AppendHTML(
    '<div class="h-16 shrink-0 flex items-center justify-center">' +
    '<div id="tabs" class="relative flex p-1 rounded-xl bg-[#eceef5]"></div></div>' +
    '<div id="list" class="' + LIST_CLASS + ' hidden">' +
    '<div id="messages" class="w-full max-w-[832px] flex flex-col gap-8 px-8 py-10"></div></div>' +
    '<div id="hometop" class="' + HOME_TOP_CLASS + '">' +
    '<div class="text-4xl font-semibold text-slate-900">Hi ' + USER_NAME + ', where should we start?</div>' +
    '<div class="text-base text-slate-500">Ask a question, attach a file or pick a suggestion.</div></div>' +
    '<div id="composerrow" class="shrink-0 flex justify-center px-8">' +
    // focus: gradient frame and glow (frame is a padding of 2px around composer)
    '<div class="w-full max-w-3xl p-0.5 rounded-[18px] bg-[#e3e6ee] shadow-xl shadow-slate-900/5 ' +
    'focus-within:bg-gradient-to-r focus-within:from-sky-400 focus-within:via-violet-500 focus-within:to-fuchsia-500 ' +
    'focus-within:shadow-2xl focus-within:shadow-violet-500/25">' +
    '<div class="flex flex-col rounded-2xl bg-white">' +
    '<div id="files" class="hidden flex gap-2 px-4 pt-4"></div>' +
    // native memo ends above tooltips of buttons (it would cover them)
    '<div class="h-28 px-5 pt-4 pb-10 cursor-text" data-action="input">' +
    '<div id="hint" class="' + HINT_CLASS + '">' + HINTS[0] + '</div><div id="input" class="hidden h-full"></div></div>' +
    '<div id="tools" class="flex items-center gap-1 px-3 pb-3"></div></div></div></div>' +
    '<div id="homebottom" class="' + HOME_BOTTOM_CLASS + '"><div class="flex gap-2">' + S + '</div></div>');
  Bind(Main);
  FTabs := Main.GetElementById('tabs');
  FList := Main.GetElementById('list');
  FMessages := Main.GetElementById('messages');
  FHomeTop := Main.GetElementById('hometop');
  FHomeBottom := Main.GetElementById('homebottom');
  FComposerRow := Main.GetElementById('composerrow');
  FFilesBox := Main.GetElementById('files');
  FHint := Main.GetElementById('hint');
  FInput := Main.GetElementById('input');
  FTools := Main.GetElementById('tools');
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.BorderStyle := bsNone;
  FMemo.WordWrap := True;
  FMemo.ScrollBars := ssAutoVertical;
  FMemo.Color := clWhite;
  FMemo.Font.Color := RGBToColor(15, 23, 42);
  FMemo.Font.Height := -Px(16);
  FMemo.OnChange := @MemoChange;
  FMemo.OnExit := @MemoExit;
  FMemo.OnKeyDown := @MemoKeyDown;
  FMemo.OnKeyPress := @MemoKeyPress;
  FInput.SetAlignControl(FMemo);
  BuildTabs;
  BuildTools;
end;

(*
  Switch of tabs: white indicator (first child) slides under active tab
*)
procedure TAgentForm.BuildTabs;
var
  I: Integer;
  S: String;
begin
  S := Format('<div class="absolute top-1 left-1 w-[%dpx] h-8 rounded-lg bg-white shadow-sm transition-transform ' +
    'duration-300 ease-out"></div>', [TAB_WIDTH]);
  for I := 0 to High(TABS) do
    S := S + Format('<div class="w-[%dpx] h-8 flex items-center justify-center text-sm font-medium cursor-pointer" ' +
      'data-action="tab" data-v="%d">%s</div>', [TAB_WIDTH, I, TABS[I]]);
  FTabs.AppendHTML(S);
  Bind(FTabs);
  SelectTab(FTab);
end;

procedure TAgentForm.SelectTab(AIndex: Integer);
const
  TAB_CLASS = 'w-[%dpx] h-8 flex items-center justify-center text-sm font-medium cursor-pointer transition-colors ';
var
  N: THtmlNode;
begin
  FTab := AIndex;
  CSSBeginUpdate;
  try
    N := FTabs.FirstChild;
    N.SetInline(Format('translate: %dpx 0', [FTab * TAB_WIDTH]));
    N := FTabs.GetNext(N);
    while Assigned(N) do begin
      if StrToIntDef(N.Attributes['data-v'], -1) = FTab then
        N.SetClass(Format(TAB_CLASS, [TAB_WIDTH]) + 'text-slate-900')
      else
        N.SetClass(Format(TAB_CLASS, [TAB_WIDTH]) + 'text-slate-500 hover:text-slate-900');
      N := FTabs.GetNext(N);
    end;
    if not FSnapshot then FHint.SetText(HINTS[FTab]).Changed;
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.BuildNav;
var
  I: Integer;
  S, C: String;
begin
  S := '';
  for I := 0 to High(SECTIONS) do begin
    if I = FSection then C := ITEM_ON else C := ITEM_OFF;
    S := S + '<div class="' + ITEM + C + '" data-action="section" data-v="' + IntToStr(I) + '">' +
      SvgIcon(SECTION_ICONS[I], 'size-[18px] text-slate-500', '1.75') + SECTIONS[I] + '</div>';
  end;
  CSSBeginUpdate;
  try
    FNav.Clear;
    FNav.AppendHTML(S);
    Bind(FNav);
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.BuildRecents;
var
  I, G: Integer;
  S, F, C: String;
  Chat: TChat;
begin
  S := '';
  G := -1;
  if Assigned(FSearch) then F := LowerCase(Trim(FSearch.Text)) else F := '';
  for I := 0 to FChats.Count - 1 do begin
    Chat := TChat(FChats[I]);
    if (F <> '') and (Pos(F, LowerCase(Chat.Title + ' ' + Chat.Preview)) = 0) then Continue;
    if Chat.Group <> G then begin
      G := Chat.Group;
      S := S + '<div class="px-3 pt-3 pb-1 text-[11px] font-semibold text-slate-400">' + GROUPS[G] + '</div>';
    end;
    if Chat = FChat then C := 'bg-[#e9ebf2] text-slate-900' else C := 'text-slate-600 hover:bg-[#eef0f5] hover:text-slate-900';
    S := S + '<div class="h-9 shrink-0 flex items-center px-3 rounded-lg cursor-pointer transition-colors ' + C +
      '" data-action="chat" data-v="' + IntToStr(I) + '"><div class="flex-1 min-w-0 text-sm truncate">' +
      Esc(Chat.Title) + '</div></div>';
  end;
  if S = '' then S := '<div class="px-3 py-2 text-[13px] text-slate-400">No threads found</div>';
  CSSBeginUpdate;
  try
    FRecents.Clear;
    FRecents.AppendHTML(S);
    Bind(FRecents);
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.BuildFiles;
var
  I: Integer;
  S: String;
begin
  S := '';
  for I := 0 to FFiles.Count - 1 do S := S + FileChip(FFiles[I], I);
  CSSBeginUpdate;
  try
    FFilesBox.Clear;
    if FFiles.Count > 0 then begin
      FFilesBox.SetClass('flex gap-2 px-4 pt-4');
      FFilesBox.AppendHTML(S);
      Bind(FFilesBox);
    end else
      FFilesBox.SetClass('hidden');
  finally
    CSSEndUpdate;
  end;
end;

(*
  Buttons of composer: attach, web search, model and send (stop while an answer is written)
*)
procedure TAgentForm.BuildTools;
const
  BUTTON = TOOL + 'text-slate-500 hover:bg-[#f1f3f8] hover:text-slate-900';
var
  S, C: String;
  I: Integer;
begin
  S := Tooltip('<div class="' + BUTTON + '">' + SvgIcon(icPlus, 'size-[18px]') + '</div>', 'Add content') +
    Tooltip('<div class="' + BUTTON + '" data-action="attach">' + SvgIcon(icPaperclip, 'size-[18px]') + '</div>', 'Attach files');
  if FWebSearch then
    S := S + Tooltip('<div class="h-9 flex items-center gap-1.5 px-2.5 rounded-lg bg-violet-50 text-violet-700 text-sm ' +
      'font-medium cursor-pointer transition-colors hover:bg-violet-100" data-action="web">' +
      SvgIcon(icGlobe, 'size-[18px]') + 'Search</div>', 'Web search is on')
  else
    S := S + Tooltip('<div class="' + BUTTON + '" data-action="web">' + SvgIcon(icGlobe, 'size-[18px]') + '</div>', 'Search the web');
  S := S + Tooltip('<div class="' + BUTTON + '">' + SvgIcon(icMic, 'size-[18px]') + '</div>', 'Voice input') +
    '<div class="flex-1"></div>';
  // model: menu painted by renderer, opens above button
  if FMenuOpen then C := 'bg-[#f1f3f8]' else C := 'hover:bg-[#f1f3f8]';
  S := S + '<div class="relative mr-2"><div class="h-9 flex items-center gap-1.5 px-3 rounded-lg text-sm font-medium ' +
    'text-slate-700 cursor-pointer transition-colors ' + C + '" data-action="model">' + MODELS[FModel];
  if FMenuOpen then S := S + SvgIcon(icChevronUp, 'size-4 text-slate-500') + '</div>'
    else S := S + SvgIcon(icChevronDown, 'size-4 text-slate-500') + '</div>';
  if FMenuOpen then begin
    S := S + '<div id="modelmenu" class="absolute bottom-full right-0 mb-2 w-72 flex flex-col gap-0.5 p-1.5 rounded-xl ' +
      'bg-white border border-[#e3e6ee] shadow-xl shadow-slate-900/10">' +
      '<div class="px-3 pt-1.5 pb-1 text-[11px] font-semibold text-slate-400">MODEL</div>';
    for I := 0 to High(MODELS) do begin
      S := S + '<div class="flex items-center gap-3 px-3 py-2 rounded-lg cursor-pointer transition-colors ' +
        'hover:bg-[#f3f4f8]" data-action="pick" data-v="' + IntToStr(I) + '"><div class="flex-1 min-w-0 flex flex-col ' +
        'gap-0.5"><div class="text-sm font-medium text-slate-900">' + MODELS[I] + '</div><div class="text-xs ' +
        'text-slate-500">' + MODEL_INFO[I] + '</div></div>';
      if I = FModel then S := S + SvgIcon(icCheck, 'size-4 shrink-0 text-violet-600', '2.5')
        else S := S + '<div class="size-4 shrink-0"></div>';
      S := S + '</div>';
    end;
    S := S + '</div>';
  end;
  S := S + '</div>';
  if Assigned(FAnswer) then
    S := S + Tooltip('<div class="size-10 flex items-center justify-center rounded-full bg-slate-900 hover:bg-slate-700 ' +
      'cursor-pointer transition-colors" data-action="send"><div class="size-3 rounded-[3px] bg-white"></div></div>',
      'Stop &middot; Esc')
  else if FCanSend then
    S := S + Tooltip('<div class="size-10 flex items-center justify-center rounded-full bg-violet-600 hover:bg-violet-500 ' +
      'text-white shadow-md shadow-violet-500/30 cursor-pointer transition-colors" data-action="send">' + SvgIcon(icArrowUp, 'size-[18px]') + '</div>',
      'Send &middot; Enter')
  else
    S := S + '<div class="size-10 flex items-center justify-center rounded-full bg-[#e7e9f0] text-white">' +
      SvgIcon(icArrowUp, 'size-[18px]') + '</div>';
  CSSBeginUpdate;
  try
    FTools.Clear;
    FTools.AppendHTML(S);
    Bind(FTools);
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.ShowView(AChat: Boolean);
begin
  if AChat then begin
    FHomeTop.SetClass('hidden');
    FHomeBottom.SetClass('hidden');
    FList.SetClass(LIST_CLASS);
    FComposerRow.SetClass('shrink-0 flex justify-center px-8 pt-2 pb-6');
  end else begin
    FHomeTop.SetClass(HOME_TOP_CLASS);
    FHomeBottom.SetClass(HOME_BOTTOM_CLASS);
    FList.SetClass(LIST_CLASS + ' hidden');
    FComposerRow.SetClass('shrink-0 flex justify-center px-8');
  end;
end;

procedure TAgentForm.ShowHome;
begin
  StopAnswer;
  FChat := nil;
  CSSBeginUpdate;
  try
    FMessages.Clear;
    ShowView(False);
    BuildRecents;
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.OpenChat(AChat: TChat);
begin
  StopAnswer;
  FChat := AChat;
  CSSBeginUpdate;
  try
    ShowView(True);
    BuildMessages(False);
    BuildRecents;
  finally
    CSSEndUpdate;
  end;
  ScrollToEnd;
end;

(*
  Messages of open chat, ASkipLast: last answer is written word by word (StartAnswer)
*)
procedure TAgentForm.BuildMessages(ASkipLast: Boolean);
var
  I, N, Last: Integer;
  M: TChatMessage;
  S, L: String;
  B: TBlock;
  Files: TStringArray;
begin
  S := '';
  N := FChat.Messages.Count;
  if ASkipLast then Dec(N);
  Last := FChat.Messages.Count - 1;
  for I := 0 to N - 1 do begin
    M := TChatMessage(FChat.Messages[I]);
    if M.FromUser then begin
      S := S + '<div class="flex flex-col items-end gap-2">';
      if M.Files <> '' then begin
        S := S + '<div class="flex gap-2">';
        Files := Trim(M.Files).Split([#10]);
        for L in Files do S := S + FileChip(Trim(L), -1);
        S := S + '</div>';
      end;
      S := S + '<div class="max-w-[85%] flex flex-col gap-1 px-4 py-3 rounded-2xl rounded-br-md bg-violet-600 text-[15px] text-white shadow-sm shadow-violet-500/20">';
      for L in M.Text.Split([#10]) do
        if Trim(L) = '' then S := S + '<div class="h-2"></div>' else S := S + '<div>' + Esc(Trim(L)) + '</div>';
      S := S + '</div></div>';
    end else begin
      S := S + '<div class="flex gap-4">' + AgentAvatar + '<div class="flex-1 min-w-0 flex flex-col gap-3 pt-1">';
      for B in M.Blocks do S := S + BlockHTML(B, True);
      S := S + '<div class="flex gap-1 -ml-2 text-slate-400">' +
        Tooltip('<div class="' + TOOL + 'size-8 hover:bg-white/70 hover:text-slate-700" data-action="copy" data-v="' +
        IntToStr(I) + '">' + SvgIcon(icCopy, 'size-4') + '</div>', 'Copy');
      if I = Last then
        S := S + Tooltip('<div class="' + TOOL + 'size-8 hover:bg-white/70 hover:text-slate-700" data-action="retry">' +
          SvgIcon(icRotateCcw, 'size-4') + '</div>', 'Regenerate');
      S := S + '</div></div></div>';
    end;
  end;
  CSSBeginUpdate;
  try
    FMessages.Clear;
    FMessages.AppendHTML(S);
    Bind(FMessages);
  finally
    CSSEndUpdate;
  end;
end;

(*
  Composer shows placeholder text in a node, native memo is shown when user writes
*)
procedure TAgentForm.ShowInput;
begin
  if not FInputShown then begin
    FInputShown := True;
    CSSBeginUpdate;
    try
      FHint.SetClass('hidden');
      FInput.SetClass('h-full');
    finally
      CSSEndUpdate;
    end;
  end;
  if FMemo.CanFocus then FMemo.SetFocus;
end;

procedure TAgentForm.Send;
var
  Prompt: String;
  M: TChatMessage;
begin
  if Assigned(FAnswer) then Exit;
  Prompt := Trim(FMemo.Text);
  if Prompt = '' then Exit;
  if FChat = nil then begin
    FChat := TChat.Create(FirstLine(Prompt), '');
    FChats.Insert(0, FChat);
  end;
  M := TChatMessage.Create;
  M.FromUser := True;
  M.Text := Prompt;
  M.Files := FFiles.Text;
  FChat.Messages.Add(M);
  M := TChatMessage.Create;
  M.Blocks := MakeAnswer(Prompt, FFiles);
  FChat.Messages.Add(M);
  FFiles.Clear;
  FMemo.Clear;
  FCanSend := False;
  CSSBeginUpdate;
  try
    ShowView(True);
    BuildMessages(True);
    BuildRecents;
    BuildFiles;
    StartAnswer(M);
  finally
    CSSEndUpdate;
  end;
  ScrollToEnd;
end;

procedure TAgentForm.StartAnswer(AMessage: TChatMessage);
begin
  FAnswer := AMessage;
  FBlock := 0;
  FTarget := nil;
  CSSBeginUpdate;
  try
    FMessages.AppendHTML('<div class="flex gap-4">' + AgentAvatar +
      '<div id="answer" class="flex-1 min-w-0 flex flex-col gap-3 pt-1">' +
      '<div id="thinking" class="h-7 flex items-center gap-1.5">' +
      '<div class="size-1.5 rounded-full bg-violet-400 animate-pulse"></div>' +
      '<div class="size-1.5 rounded-full bg-violet-400 animate-pulse"></div>' +
      '<div class="size-1.5 rounded-full bg-violet-400 animate-pulse"></div>' +
      '<div class="ml-1 text-sm text-slate-500">Thinking</div></div></div></div>');
    FAnswerBox := FMessages.GetElementById('answer');
    FAnswerBox.Id := '';
    FThinking := FAnswerBox.FirstChild;
    BuildTools;
  finally
    CSSEndUpdate;
  end;
  FThinkUntil := GetTickCount64 + 500 + QWord(Random(500));
  FTimer.Enabled := True;
end;

(*
  Answer is stopped: only the written part is kept
*)
procedure TAgentForm.StopAnswer;
var
  Lines: TStringArray;
  I: Integer;
  S: String;
begin
  if FAnswer = nil then Exit;
  if FTarget = nil then
    SetLength(FAnswer.Blocks, FBlock)
  else begin
    SetLength(FAnswer.Blocks, FBlock + 1);
    if FAnswer.Blocks[FBlock].Kind = 'c' then begin
      Lines := CodeLines(FAnswer.Blocks[FBlock].Text);
      S := CodeLanguage(FAnswer.Blocks[FBlock].Text);
      for I := 0 to Min(FPos, Length(Lines)) - 1 do S := S + #10 + Lines[I];
      FAnswer.Blocks[FBlock].Text := S;
    end else
      FAnswer.Blocks[FBlock].Text := Copy(FAnswer.Blocks[FBlock].Text, 1, FPos);
  end;
  if Length(FAnswer.Blocks) = 0 then AddBlock(FAnswer.Blocks, 'p', 'Stopped.');
  FinishAnswer;
end;

procedure TAgentForm.FinishAnswer;
var
  B: TBlock;
begin
  FTimer.Enabled := False;
  if FChat.Preview = '' then
    for B in FAnswer.Blocks do
      if B.Kind = 'p' then begin
        FChat.Preview := B.Text;
        Break;
      end;
  FAnswer := nil;
  FAnswerBox := nil;
  FTarget := nil;
  FThinking := nil;
  CSSBeginUpdate;
  try
    BuildMessages(False);        // copy and retry buttons
    BuildRecents;
    BuildTools;
  finally
    CSSEndUpdate;
  end;
end;

procedure TAgentForm.ScrollToEnd;
begin
  if FList.SetScroll(0, FList.ScrollMax.Y) then FList.Changed;
end;

(*
  Next words of answer (code: next line)
*)
procedure TAgentForm.AnswerTick(Sender: TObject);
var
  B: TBlock;
  AtEnd: Boolean;
  Lines: TStringArray;
  I: Integer;
begin
  if (FAnswer = nil) or (GetTickCount64 < FThinkUntil) then Exit;
  if FBlock > High(FAnswer.Blocks) then begin
    FinishAnswer;
    Exit;
  end;
  AtEnd := FList.ScrollY >= FList.ScrollMax.Y - 8;
  CSSBeginUpdate;
  try
    if Assigned(FThinking) then begin
      FAnswerBox.Delete(FThinking);
      FThinking := nil;
    end;
    B := FAnswer.Blocks[FBlock];
    if FTarget = nil then begin
      FAnswerBox.AppendHTML(BlockHTML(B, False));
      FTarget := FindByAttr(LastChild(FAnswerBox), 'data-t');
      FPos := 0;
    end;
    if B.Kind = 'c' then begin
      Lines := CodeLines(B.Text);
      if FPos < Length(Lines) then FTarget.AppendHTML(CodeLineHTML(Lines[FPos]));
      Inc(FPos);
      if FPos >= Length(Lines) then FTarget := nil;
    end else begin
      for I := 1 to 2 do begin     // two words
        while (FPos < Length(B.Text)) and (B.Text[FPos + 1] = ' ') do Inc(FPos);
        while (FPos < Length(B.Text)) and (B.Text[FPos + 1] <> ' ') do Inc(FPos);
      end;
      FTarget.SetText(Copy(B.Text, 1, FPos)).Changed;
      if FPos >= Length(B.Text) then FTarget := nil;
    end;
    if FTarget = nil then Inc(FBlock);
    FShape.Changed;
  finally
    CSSEndUpdate;
  end;
  if AtEnd then ScrollToEnd;
end;

procedure TAgentForm.ActionClick(Sender: TObject);
var
  A: String;
  V, I: Integer;
  N: THtmlNode;
  Dlg: TOpenDialog;
  M: TChatMessage;
begin
  N := THtmlNode(Sender);
  A := N.Attributes['data-action'];
  V := StrToIntDef(N.Attributes['data-v'], 0);
  if A = 'new' then ShowHome
  else if A = 'search' then begin
    FSearchShown := not FSearchShown;
    CSSBeginUpdate;
    try
      if not FSearchShown then begin
        FSearchBox.SetClass('hidden');
        FSearch.Text := '';
      end else
        FSearchBox.SetClass('h-9 flex items-center gap-2 mx-1 px-3 rounded-lg bg-white border border-[#e3e6ee] ' +
          'text-slate-400 focus-within:border-violet-300 focus-within:ring-4 focus-within:ring-violet-500/10');
    finally
      CSSEndUpdate;
    end;
    if FSearchShown and FSearch.CanFocus then FSearch.SetFocus;
  end else if A = 'section' then begin
    FSection := V;
    BuildNav;
  end else if A = 'chat' then
    OpenChat(TChat(FChats[V]))
  else if A = 'tab' then
    SelectTab(V)
  else if A = 'quick' then begin
    FMemo.Text := QUICK[V].Prompt;
    MemoChange(FMemo);            // OnChange is not called for text set in code on all platforms
    ShowInput;
    FMemo.SelStart := Length(FMemo.Text);
  end else if A = 'input' then
    ShowInput
  else if A = 'attach' then begin
    Dlg := TOpenDialog.Create(Self);
    try
      Dlg.Options := Dlg.Options + [ofAllowMultiSelect];
      if Dlg.Execute then begin
        for I := 0 to Dlg.Files.Count - 1 do FFiles.Add(ExtractFileName(Dlg.Files[I]));
        BuildFiles;
      end;
    finally
      Dlg.Free;
    end;
  end else if A = 'unattach' then begin
    if V < FFiles.Count then FFiles.Delete(V);
    BuildFiles;
  end else if A = 'web' then begin
    FWebSearch := not FWebSearch;
    BuildTools;
  end else if A = 'model' then
    SetMenu(not FMenuOpen)
  else if A = 'pick' then begin
    FModel := V;
    SetMenu(False);
  end else if A = 'send' then begin
    if Assigned(FAnswer) then StopAnswer else Send;
  end else if A = 'copy' then begin
    M := TChatMessage(FChat.Messages[V]);
    Clipboard.AsText := BlocksText(M.Blocks);
  end else if A = 'retry' then begin
    // last answer is written again
    if (FAnswer = nil) and (FChat.Messages.Count >= 2) then begin
      M := TChatMessage(FChat.Messages[FChat.Messages.Count - 2]);
      TChatMessage(FChat.Messages.Last).Blocks := MakeAnswer(M.Text, nil);
      CSSBeginUpdate;
      try
        BuildMessages(True);
        StartAnswer(TChatMessage(FChat.Messages.Last));
      finally
        CSSEndUpdate;
      end;
      ScrollToEnd;
    end;
  end;
end;

(*
  Model menu. Native memo is above everything painted by renderer, so while the menu is open its text is
  painted by renderer instead (placeholder node) and memo is hidden.
*)
procedure TAgentForm.SetMenu(AOpen: Boolean);
begin
  if FMenuOpen = AOpen then Exit;
  FMenuOpen := AOpen;
  CSSBeginUpdate;
  try
    if AOpen and FInputShown then begin
      FSnapshot := FMemo.Text <> '';
      if FSnapshot then begin
        FHint.SetClass('text-base text-slate-900');
        FHint.SetText(FMemo.Text).Changed;
      end else
        FHint.SetClass(HINT_CLASS);
      FInput.SetClass('hidden h-full');
      FInputShown := False;
    end else if not AOpen and FSnapshot then begin
      FSnapshot := False;
      FHint.SetClass('hidden');
      FHint.SetText(HINTS[FTab]).Changed;
      FInput.SetClass('h-full');
      FInputShown := True;
    end;
    BuildTools;
  finally
    CSSEndUpdate;
  end;
  if FInputShown and FMemo.CanFocus then FMemo.SetFocus;
end;

// click outside of model menu closes it
procedure TAgentForm.ShapeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  N: THtmlNode;
begin
  if not FMenuOpen then Exit;
  N := FShape.Body.NodeAtPosition(Point(X, Y), False);
  while Assigned(N) and (N.Id <> 'modelmenu') and (N.Attributes['data-action'] <> 'model') do N := N.ParentNode;
  if N = nil then SetMenu(False);
end;

procedure TAgentForm.MemoChange(Sender: TObject);
var
  C: Boolean;
begin
  C := Trim(FMemo.Text) <> '';
  if C = FCanSend then Exit;
  FCanSend := C;
  BuildTools;
end;

procedure TAgentForm.MemoExit(Sender: TObject);
begin
  if (FMemo.Text <> '') or not FInputShown then Exit;
  FInputShown := False;
  CSSBeginUpdate;
  try
    FHint.SetClass(HINT_CLASS);
    FInput.SetClass('hidden h-full');
  finally
    CSSEndUpdate;
  end;
end;

// Enter sends message, Shift+Enter is a new line
procedure TAgentForm.MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and not (ssShift in Shift) then begin
    Key := 0;
    FEatReturn := True;        // character of key is not inserted
    Send;
  end;
end;

procedure TAgentForm.MemoKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key in [#10, #13]) and FEatReturn then Key := #0;
  FEatReturn := False;
end;

procedure TAgentForm.SearchChange(Sender: TObject);
begin
  BuildRecents;
end;

procedure TAgentForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and FMenuOpen then begin
    SetMenu(False);
    Key := 0;
  end else if (Key = VK_ESCAPE) and Assigned(FAnswer) then begin
    StopAnswer;
    Key := 0;
  end;
end;

end.
