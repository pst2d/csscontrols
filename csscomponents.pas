unit csscomponents;

(*
  Ready made components built on TCSSShape (palette page CSS). Each component only sets utility classes
  of its nodes, painting, hover, active state, transitions and dark mode are done by the engine.
  Tailwind utility classes are enabled by this unit (initialization), unless application set its own resolver.

  TCSSButton  - Caption, Kind, OnClick
  TCSSToggle  - Checked, Caption, OnChange (animated switch)
  TCSSBadge   - Caption, ColorName
  TCSSAvatar  - Initials, ColorName, ImageName (image registered by CSSRegisterImage)
  TCSSTabs    - Tabs, TabIndex, OnChange (segmented control)
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Controls, cssbase, CSSCtrls;

type
  TCSSColorName = (ccSlate, ccIndigo, ccGreen, ccAmber, ccRed, ccSky, ccPink);
  TCSSButtonKind = (cbkPrimary, cbkSecondary, cbkDanger, cbkGhost);

  { TCSSComponent - base: one node with classes, look is updated by UpdateLook }

  TCSSComponent = class(TCSSShape)
  protected
    FNode: THtmlNode;
    procedure UpdateLook; virtual; abstract;
    procedure Restyle;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { TCSSButton }

  TCSSButton = class(TCSSComponent)
  private
    FCaption: String;
    FKind: TCSSButtonKind;
    procedure SetCaption(const AValue: String);
    procedure SetKind(AValue: TCSSButtonKind);
  protected
    procedure UpdateLook; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: String read FCaption write SetCaption;
    property Kind: TCSSButtonKind read FKind write SetKind default cbkPrimary;
    property OnClick;
  end;

  { TCSSToggle }

  TCSSToggle = class(TCSSComponent)
  private
    FChecked: Boolean;
    FCaption: String;
    FTrack, FKnob, FLabel: THtmlNode;
    FOnChange: TNotifyEvent;
    procedure SetCaption(const AValue: String);
    procedure SetChecked(AValue: Boolean);
  protected
    procedure UpdateLook; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
  published
    property Caption: String read FCaption write SetCaption;
    property Checked: Boolean read FChecked write SetChecked default False;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
  end;

  { TCSSBadge }

  TCSSBadge = class(TCSSComponent)
  private
    FCaption: String;
    FColor: TCSSColorName;
    procedure SetCaption(const AValue: String);
    procedure SetColorName(AValue: TCSSColorName);
  protected
    procedure UpdateLook; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: String read FCaption write SetCaption;
    property ColorName: TCSSColorName read FColor write SetColorName default ccSlate;
    property OnClick;
  end;

  { TCSSAvatar }

  TCSSAvatar = class(TCSSComponent)
  private
    FInitials: String;
    FColor: TCSSColorName;
    FImageName: String;
    FFontHeight: Integer;          // height used for font size
    procedure SetNodeClass;
    procedure SetInitials(const AValue: String);
    procedure SetColorName(AValue: TCSSColorName);
    procedure SetImageName(const AValue: String);
  protected
    procedure UpdateLook; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Initials: String read FInitials write SetInitials;
    property ColorName: TCSSColorName read FColor write SetColorName default ccIndigo;
    property ImageName: String read FImageName write SetImageName;   // name or file of image (CSSRegisterImage)
    property OnClick;
  end;

  { TCSSTabs }

  TCSSTabs = class(TCSSComponent)
  private
    FTabs: TStrings;
    FTabIndex: Integer;
    FOnChange: TNotifyEvent;
    FIndicator: THtmlNode;         // pill under active tab, moved with transition
    FIndicatorWidth: Integer;      // control width used for indicator position
    procedure BuildTabs;
    procedure PlaceIndicator;
    procedure SetTabs(AValue: TStrings);
    procedure SetTabIndex(AValue: Integer);
    procedure TabsChanged(Sender: TObject);
    procedure TabClick(Sender: TObject);
  protected
    procedure UpdateLook; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Tabs: TStrings read FTabs write SetTabs;
    property TabIndex: Integer read FTabIndex write SetTabIndex default 0;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

procedure Register;

implementation
{$R csscomponents.res}   // palette icons (PNG 24, 36 and 48 px)

uses
  csstailwind;

const
  COLOR_NAMES: array[TCSSColorName] of String = ('slate', 'indigo', 'green', 'amber', 'red', 'sky', 'pink');

procedure Register;
begin
  RegisterComponents('CSS', [TCSSButton, TCSSToggle, TCSSBadge, TCSSAvatar, TCSSTabs]);
end;

{ TCSSComponent }

constructor TCSSComponent.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Body.SetClass('h-full flex');
  FNode := HTMLNode('').AppendTo(Body);
end;

procedure TCSSComponent.Restyle;
begin
  Body.ApplyStyles;
  Changed;
end;

{ TCSSButton }

constructor TCSSButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaption := 'Button';
  SetInitialBounds(0, 0, 100, 36);
  UpdateLook;
end;

procedure TCSSButton.SetCaption(const AValue: String);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  UpdateLook;
end;

procedure TCSSButton.SetKind(AValue: TCSSButtonKind);
begin
  if FKind = AValue then Exit;
  FKind := AValue;
  UpdateLook;
end;

procedure TCSSButton.UpdateLook;
const
  KIND_CLS: array[TCSSButtonKind] of String = (
    'bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 text-white shadow-sm',
    'bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200',
    'bg-rose-600 hover:bg-rose-500 active:bg-rose-700 text-white shadow-sm',
    'text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800');
begin
  FNode.Text := FCaption;
  FNode.SetClass('grow flex items-center justify-center px-4 rounded-lg text-sm font-semibold cursor-pointer transition ' + KIND_CLS[FKind]);
  Restyle;
end;

{ TCSSToggle }

constructor TCSSToggle.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTrack := HTMLNode('').AppendTo(FNode);
  FKnob := HTMLNode('').AppendTo(FTrack);
  FLabel := HTMLNode('').AppendTo(FNode);
  SetInitialBounds(0, 0, 160, 28);
  UpdateLook;
end;

procedure TCSSToggle.SetCaption(const AValue: String);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  UpdateLook;
end;

procedure TCSSToggle.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then Exit;
  FChecked := AValue;
  UpdateLook;
  if Assigned(FOnChange) and not (csLoading in ComponentState) then FOnChange(Self);
end;

procedure TCSSToggle.Click;
begin
  Checked := not Checked;
  inherited Click;
end;

procedure TCSSToggle.UpdateLook;
begin
  FNode.SetClass('grow flex items-center gap-3 cursor-pointer');
  // knob is moved by translate with transition (animated)
  if FChecked then begin
    FTrack.SetClass('w-11 h-6 shrink-0 p-0.5 rounded-full bg-indigo-600 transition-colors duration-200');
    FKnob.SetClass('size-5 rounded-full bg-white shadow translate-x-5 transition-transform duration-200 ease-out');
  end else begin
    FTrack.SetClass('w-11 h-6 shrink-0 p-0.5 rounded-full bg-slate-300 dark:bg-slate-600 transition-colors duration-200');
    FKnob.SetClass('size-5 rounded-full bg-white shadow translate-x-0 transition-transform duration-200 ease-out');
  end;
  FLabel.Text := FCaption;
  FLabel.SetClass('text-sm text-slate-700 dark:text-slate-200 truncate');
  Restyle;
end;

{ TCSSBadge }

constructor TCSSBadge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaption := 'Badge';
  SetInitialBounds(0, 0, 70, 24);
  UpdateLook;
end;

procedure TCSSBadge.SetCaption(const AValue: String);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  UpdateLook;
end;

procedure TCSSBadge.SetColorName(AValue: TCSSColorName);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  UpdateLook;
end;

procedure TCSSBadge.UpdateLook;
var
  C: String;
begin
  C := COLOR_NAMES[FColor];
  FNode.Text := FCaption;
  FNode.SetClass(Format('grow flex items-center justify-center px-2.5 rounded-full text-xs font-medium bg-%s-100 text-%s-700 ' +
    'dark:bg-%s-500/20 dark:text-%s-300', [C, C, C, C]));
  Restyle;
end;

{ TCSSAvatar }

constructor TCSSAvatar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInitials := 'AB';
  FColor := ccIndigo;
  SetInitialBounds(0, 0, 40, 40);
  UpdateLook;
end;

procedure TCSSAvatar.SetInitials(const AValue: String);
begin
  if FInitials = AValue then Exit;
  FInitials := AValue;
  UpdateLook;
end;

procedure TCSSAvatar.SetColorName(AValue: TCSSColorName);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  UpdateLook;
end;

procedure TCSSAvatar.SetImageName(const AValue: String);
begin
  if FImageName = AValue then Exit;
  FImageName := AValue;
  UpdateLook;
end;

(*
  Font size follows size of avatar. Only styles and layout of avatar are updated: Changed would ask
  for new preferred size while LCL is resizing the control (loop).
*)
procedure TCSSAvatar.Resize;
begin
  inherited Resize;
  if Assigned(FNode) and (Height <> FFontHeight) then begin
    SetNodeClass;
    Body.ApplyStyles;
    Body.LayoutTo(0, 0, Width, Height);
    Invalidate;
  end;
end;

procedure TCSSAvatar.UpdateLook;
begin
  SetNodeClass;
  Restyle;
end;

procedure TCSSAvatar.SetNodeClass;
var
  C: String;
begin
  FFontHeight := Height;
  C := COLOR_NAMES[FColor];
  if FImageName <> '' then begin
    FNode.Text := '';
    FNode.SetClass('grow rounded-full bg-cover bg-center bg-[url(' + FImageName + ')]');
  end else begin
    FNode.Text := FInitials;
    FNode.SetClass(Format('grow flex items-center justify-center rounded-full bg-gradient-to-br from-%s-400 to-%s-600 ' +
      'text-white font-semibold text-[%dpx]', [C, C, Max(8, Round(Height * 0.38))]));
  end;
end;

{ TCSSTabs }

constructor TCSSTabs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTabs := TStringList.Create;
  FTabs.Text := 'Day'#10'Week'#10'Month';
  TStringList(FTabs).OnChange := @TabsChanged;
  SetInitialBounds(0, 0, 240, 36);
  BuildTabs;
end;

destructor TCSSTabs.Destroy;
begin
  FreeAndNil(FTabs);
  inherited Destroy;
end;

procedure TCSSTabs.SetTabs(AValue: TStrings);
begin
  FTabs.Assign(AValue);
end;

procedure TCSSTabs.SetTabIndex(AValue: Integer);
begin
  if FTabIndex = AValue then Exit;
  FTabIndex := AValue;
  UpdateLook;
  if Assigned(FOnChange) and not (csLoading in ComponentState) then FOnChange(Self);
end;

procedure TCSSTabs.TabsChanged(Sender: TObject);
begin
  BuildTabs;
end;

procedure TCSSTabs.TabClick(Sender: TObject);
begin
  TabIndex := StrToIntDef(THtmlNode(Sender).Attributes['data-index'], 0);
end;

(*
  Nodes of tabs: container scrolls horizontally when tabs don't fit, first child is the indicator
*)
procedure TCSSTabs.BuildTabs;
var
  I: Integer;
  N: THtmlNode;
begin
  if FTabs = nil then Exit;
  FNode.Clear;
  FNode.SetClass('grow relative flex p-1 gap-1 rounded-lg bg-slate-100 dark:bg-slate-800 overflow-x-auto scrollbar-none');
  FIndicator := HTMLNode('absolute top-1 bottom-1 rounded-md bg-white dark:bg-slate-600 shadow-sm transition-transform duration-200 ease-out').AppendTo(FNode);
  for I := 0 to FTabs.Count - 1 do begin
    N := HTMLNode('', FTabs[I]);
    N.Attributes['data-index'] := IntToStr(I);
    N.OnClick := @TabClick;
    N.AppendTo(FNode);
  end;
  UpdateLook;
end;

procedure TCSSTabs.UpdateLook;
const
  TAB = 'grow shrink-0 flex items-center justify-center px-3 rounded-md text-sm whitespace-nowrap cursor-pointer transition-colors ';
var
  N: THtmlNode;
begin
  if (FTabs = nil) or (FIndicator = nil) then Exit;
  N := FIndicator.ParentNode.GetNext(FIndicator);
  while Assigned(N) do begin
    if StrToIntDef(N.Attributes['data-index'], -1) = FTabIndex then
      N.SetClass(TAB + 'font-medium text-slate-900 dark:text-white')
    else
      N.SetClass(TAB + 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white');
    N := N.ParentNode.GetNext(N);
  end;
  Restyle;
  PlaceIndicator;
  Restyle;
end;

(*
  Indicator is moved under active tab (translate is animated), width is set at once.
  Layout is in device pixels, CSS px are scaled by PixelRatio (high dpi on Windows and Linux).
*)
procedure TCSSTabs.PlaceIndicator;
var
  N, Active: THtmlNode;
  R, VP: TRect;
  K: Single;
  FS: TFormatSettings;
begin
  FIndicatorWidth := Width;
  Active := nil;
  N := FIndicator.ParentNode.GetNext(FIndicator);
  while Assigned(N) and (Active = nil) do begin
    if StrToIntDef(N.Attributes['data-index'], -1) = FTabIndex then Active := N;
    N := N.ParentNode.GetNext(N);
  end;
  if Active = nil then begin
    FIndicator.InlineStyle := 'display: none';
    Exit;
  end;
  R := Active.CompSize.ContentRect;
  VP := FNode.PaddingBox;
  K := Body.PixelRatio;
  if K <= 0 then K := 1;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FIndicator.InlineStyle := Format('left: 0; width: %.2fpx; translate: %.2fpx 0', [R.Width / K, (R.Left - VP.Left) / K], FS);
  // active tab is scrolled into view
  if R.Left - FNode.ScrollX < VP.Left then FNode.SetScroll(R.Left - VP.Left - 4, 0)
  else if R.Right - FNode.ScrollX > VP.Right then FNode.SetScroll(R.Right - VP.Right + 4, 0);
end;

(*
  Tab widths depend on control width (align, anchors, form scaling), indicator follows them.
  Changed is not called here (InvalidatePreferredSize during autosize raises a loop exception).
*)
procedure TCSSTabs.Resize;
begin
  inherited Resize;
  if Assigned(FIndicator) and (Width <> FIndicatorWidth) then begin
    CSSBeginUpdate;
    try
      Body.LayoutTo(0, 0, Width, Height);
      PlaceIndicator;
    finally
      CSSEndUpdate;
    end;
    Body.LayoutTo(0, 0, Width, Height);
    Invalidate;
  end;
end;

initialization
  // components are styled by utility classes, so they work at runtime without any setup
  if CSSUtilityResolver = nil then CSSTailwindEnable;

end.
