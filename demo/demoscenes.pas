(*
  Demo scenes for csscontrols, used by demo application and PNG renderer
*)
unit demoscenes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, cssbase, csshtml;

type
  TBuildSceneProc = procedure(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  TDemoScene = record
    Name: String;
    Build: TBuildSceneProc;
    Height: Integer;       // height for PNG renderer (app like scenes use h-full), 0 = height of content
  end;

procedure BuildCard(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildButtons(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildFlex(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildResponsive(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildTypography(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildDashboard(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildStyleSheet(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildBorders(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildBackgrounds(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildShadows(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildHtml(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildTransforms(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildDropzone(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildChatApp(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildForms(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildSettings(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildShop(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildCalendar(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildGrid(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
procedure BuildAnimations(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);

const
  DEMO_SCENES: array[0..19] of TDemoScene = (
    (Name: 'Card'; Build: @BuildCard; Height: 0),
    (Name: 'Buttons'; Build: @BuildButtons; Height: 0),
    (Name: 'Flexbox'; Build: @BuildFlex; Height: 0),
    (Name: 'Responsive'; Build: @BuildResponsive; Height: 0),
    (Name: 'Typography'; Build: @BuildTypography; Height: 0),
    (Name: 'Dashboard'; Build: @BuildDashboard; Height: 0),
    (Name: 'Stylesheet'; Build: @BuildStyleSheet; Height: 0),
    (Name: 'Borders'; Build: @BuildBorders; Height: 0),
    (Name: 'Backgrounds'; Build: @BuildBackgrounds; Height: 0),
    (Name: 'Shadows'; Build: @BuildShadows; Height: 0),
    (Name: 'HTML'; Build: @BuildHtml; Height: 0),
    (Name: 'Transforms'; Build: @BuildTransforms; Height: 0),
    (Name: 'Dropzone'; Build: @BuildDropzone; Height: 0),
    (Name: 'Chat app'; Build: @BuildChatApp; Height: 680),
    (Name: 'Forms'; Build: @BuildForms; Height: 0),
    (Name: 'Settings'; Build: @BuildSettings; Height: 760),
    (Name: 'Shop'; Build: @BuildShop; Height: 760),
    (Name: 'Calendar'; Build: @BuildCalendar; Height: 720),
    (Name: 'Grid'; Build: @BuildGrid; Height: 0),
    (Name: 'Animations'; Build: @BuildAnimations; Height: 0)
  );

implementation

function N(AParent: THtmlNode; const AClass: String; const AText: String = ''): THtmlNode;
begin
  Result := HTMLNode(AClass, AText).AppendTo(AParent);
end;

procedure BuildCard(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
var
  Card, Info: THtmlNode;
begin
  ABody.SetClass('p-8 bg-slate-100');
  Card := N(ABody, 'max-w-sm mx-auto flex items-center gap-4 p-6 bg-white rounded-xl shadow-lg');
  N(Card, 'size-12 shrink-0 rounded-full bg-sky-500');
  Info := N(Card, 'flex flex-col gap-1');
  N(Info, 'text-xl font-medium text-black', 'ChitChat');
  N(Info, 'text-slate-500', 'You have a new message!');

  Card := N(ABody, 'max-w-sm mx-auto mt-6 p-6 bg-white rounded-2xl shadow-md flex flex-col gap-4');
  Info := N(Card, 'flex items-center gap-3');
  N(Info, 'size-10 shrink-0 rounded-full bg-violet-500');
  N(Info, 'grow font-semibold text-slate-900', 'Erin Lindford');
  N(Info, 'px-2 py-1 text-xs font-semibold rounded-full bg-emerald-100 text-emerald-700', 'Online');
  N(Card, 'text-slate-600', 'Product engineer. Building user interfaces with utility classes in Lazarus.');
  Info := N(Card, 'flex gap-2 justify-end');
  N(Info, 'px-4 py-2 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-100 cursor-pointer', 'Message');
  N(Info, 'px-4 py-2 rounded-lg bg-violet-600 hover:bg-violet-700 active:bg-violet-800 text-white font-semibold cursor-pointer shadow-md shadow-violet-500/40', 'Follow');
end;

(*
  Tooltip: transparent absolute child shown by group-hover with fade (pure CSS, no code)
*)
function Tooltip(const AControl, AText, APlace: String): String;
var
  Pos, Arrow: String;
begin
  if APlace = 'bottom' then begin
    Pos := 'top-full left-1/2 -translate-x-1/2 mt-2';
    Arrow := 'bottom-full left-1/2 -translate-x-1/2 -mb-1';
  end else
  if APlace = 'right' then begin
    Pos := 'left-full top-1/2 -translate-y-1/2 ml-2';
    Arrow := 'right-full top-1/2 -translate-y-1/2 -mr-1';
  end else
  if APlace = 'left' then begin
    Pos := 'right-full top-1/2 -translate-y-1/2 mr-2';
    Arrow := 'left-full top-1/2 -translate-y-1/2 -ml-1';
  end else begin
    Pos := 'bottom-full left-1/2 -translate-x-1/2 mb-2';
    Arrow := 'top-full left-1/2 -translate-x-1/2 -mt-1';
  end;
  Result := '<div class="group relative">' + AControl +
    '<div class="absolute ' + Pos + ' z-10 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap px-2.5 py-1.5 rounded-md bg-slate-900 text-white text-xs font-medium shadow-lg">' +
    AText + '<div class="absolute ' + Arrow + ' size-2 rotate-45 bg-slate-900"></div></div></div>';
end;

procedure BuildButtons(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
var
  Row: THtmlNode;
begin
  ABody.SetClass('p-8 bg-white flex flex-col gap-6');
  Row := N(ABody, 'flex flex-wrap gap-3 items-center');
  N(Row, 'px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-semibold cursor-pointer', 'Primary');
  N(Row, 'px-4 py-2 rounded-lg border border-slate-300 hover:bg-slate-100 active:bg-slate-200 text-slate-700 cursor-pointer', 'Secondary');
  N(Row, 'px-4 py-2 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white cursor-pointer', 'Pill button');
  N(Row, 'px-4 py-2 rounded-lg text-red-600 hover:bg-red-50 cursor-pointer', 'Delete');
  N(Row, 'px-4 py-2 rounded-lg text-slate-400 border border-dashed border-slate-300 cursor-not-allowed', 'Disabled');
  Row := N(ABody, 'flex flex-wrap gap-2 items-center');
  N(Row, 'px-2 py-1 rounded bg-red-100 text-red-700 text-xs font-medium', 'Error');
  N(Row, 'px-2 py-1 rounded bg-amber-100 text-amber-800 text-xs font-medium', 'Warning');
  N(Row, 'px-2 py-1 rounded bg-green-100 text-green-700 text-xs font-medium', 'Success');
  N(Row, 'px-2 py-1 rounded bg-sky-100 text-sky-700 text-xs font-medium', 'Info');
  Row := N(ABody, 'flex items-center gap-4');
  N(Row, 'size-16 rounded-full bg-rose-400 border-4 border-rose-200');
  N(Row, 'size-16 rounded-2xl bg-teal-400');
  N(Row, 'size-16 rounded-t-full bg-orange-400');
  N(Row, 'size-16 rounded-tl-3xl rounded-br-3xl bg-indigo-400');
  N(Row, 'size-16 rounded-full border-8 border-indigo-200 bg-indigo-500');
  // tooltips (hover)
  N(ABody, 'pt-6 text-sm font-semibold text-slate-500', 'Tooltips (hover)');
  ABody.AppendHTML('<div class="flex flex-wrap items-center gap-4 pt-8 pb-10">' +
    Tooltip('<div class="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-700 text-white font-semibold cursor-pointer">Save</div>', 'Save changes &middot; Ctrl+S', 'top') +
    Tooltip('<div class="size-10 rounded-full border border-slate-300 hover:bg-slate-100 flex items-center justify-center text-slate-600 cursor-pointer">?</div>', 'Help and documentation', 'bottom') +
    Tooltip('<div class="px-3 py-2 rounded-lg bg-rose-50 text-rose-600 hover:bg-rose-100 cursor-pointer">Delete</div>', 'Cannot be undone', 'right') +
    '</div>');
end;

procedure BuildFlex(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  JUSTIFY: array[0..5] of String = ('justify-start', 'justify-center', 'justify-end', 'justify-between', 'justify-around', 'justify-evenly');
  ITEMS: array[0..3] of String = ('items-start', 'items-center', 'items-end', 'items-stretch');
var
  I, J: Integer;
  Row, Col, Box: THtmlNode;
begin
  ABody.SetClass('p-6 bg-white flex flex-col gap-2');
  for I := 0 to High(JUSTIFY) do begin
    N(ABody, 'text-sm font-mono text-slate-500', JUSTIFY[I]);
    Row := N(ABody, 'flex gap-2 p-2 bg-slate-100 rounded-lg ' + JUSTIFY[I]);
    for J := 1 to 3 do N(Row, 'size-10 rounded-md bg-indigo-500 text-white flex items-center justify-center font-bold', IntToStr(J));
  end;
  Row := N(ABody, 'flex gap-4 mt-4');
  for I := 0 to High(ITEMS) do begin
    Col := N(Row, 'grow basis-0 flex flex-col gap-1');
    N(Col, 'text-sm font-mono text-slate-500', ITEMS[I]);
    Box := N(Col, 'flex gap-2 h-24 p-2 bg-slate-100 rounded-lg ' + ITEMS[I]);
    N(Box, 'w-6 h-6 rounded bg-pink-500');
    N(Box, 'w-6 h-10 rounded bg-pink-400');
    N(Box, 'w-6 min-h-4 rounded bg-pink-300');
  end;
end;

procedure BuildResponsive(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  COLORS: array[0..5] of String = ('bg-amber-400', 'bg-orange-400', 'bg-rose-400', 'bg-fuchsia-400', 'bg-violet-400', 'bg-sky-400');
var
  I: Integer;
  Grid: THtmlNode;
begin
  ABody.SetClass('p-4 bg-white flex flex-col gap-4');
  N(ABody, 'text-sm text-slate-600', 'Resize window: 1 column, sm: 2 columns, lg: 3 columns (breakpoints are based on control width)');
  Grid := N(ABody, 'flex flex-wrap gap-4');
  for I := 0 to High(COLORS) do
    N(Grid, 'basis-full sm:basis-[45%] lg:basis-[30%] grow h-20 rounded-xl flex items-center justify-center text-white text-2xl font-bold ' + COLORS[I], IntToStr(I + 1));
end;

procedure BuildTypography(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
var
  Box: THtmlNode;
begin
  ABody.SetClass('p-8 bg-white flex flex-col gap-3 text-slate-800');
  N(ABody, 'text-3xl font-bold text-slate-900', 'Typography');
  N(ABody, 'text-xs', 'text-xs: The quick brown fox jumps over the lazy dog');
  N(ABody, 'text-sm', 'text-sm: The quick brown fox jumps over the lazy dog');
  N(ABody, 'text-base', 'text-base: The quick brown fox jumps over the lazy dog');
  N(ABody, 'text-lg font-semibold', 'text-lg font-semibold');
  N(ABody, 'text-2xl font-light', 'text-2xl font-light');
  N(ABody, 'italic text-slate-600', 'italic text');
  N(ABody, 'underline text-blue-600', 'underline link');
  N(ABody, 'line-through text-slate-400', 'line-through');
  N(ABody, 'font-mono text-sm bg-slate-100 p-2 rounded', 'font-mono: Body.SetClass(''flex gap-2'');');
  Box := N(ABody, 'max-w-md p-4 rounded-lg bg-amber-50 border border-amber-200 text-amber-900');
  Box.Text := 'Long text is wrapped inside its box. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.';
  N(ABody, 'text-center text-slate-500 text-sm', 'text-center');
  N(ABody, 'text-right text-slate-500 text-sm', 'text-right');
end;

procedure BuildDashboard(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  MENU: array[0..4] of String = ('Dashboard', 'Customers', 'Orders', 'Reports', 'Settings');
  STAT_DATA: array[0..2, 0..2] of String = (('Revenue', '12 480 EUR', 'text-emerald-600'), ('Orders', '312', 'text-sky-600'), ('Returns', '4', 'text-rose-600'));
var
  I: Integer;
  Side, Main, Head, Stats, Card, Table, Row: THtmlNode;
begin
  ABody.SetClass('flex bg-slate-100 min-h-[420px]');
  Side := N(ABody, 'w-48 shrink-0 bg-slate-800 p-4 flex flex-col gap-1');
  N(Side, 'text-white font-bold text-lg mb-4', 'Acme');
  for I := 0 to High(MENU) do
    if I = 0 then N(Side, 'px-3 py-2 rounded-md bg-slate-700 text-white', MENU[I])
      else N(Side, 'px-3 py-2 rounded-md text-slate-300 hover:bg-slate-700 hover:text-white cursor-pointer', MENU[I]);
  Main := N(ABody, 'grow p-6 flex flex-col gap-6 min-w-0');
  Head := N(Main, 'flex items-center justify-between');
  N(Head, 'text-2xl font-semibold text-slate-900', 'Dashboard');
  N(Head, 'px-3 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium cursor-pointer', 'New order');
  Stats := N(Main, 'flex flex-wrap gap-4');
  for I := 0 to High(STAT_DATA) do begin
    Card := N(Stats, 'grow basis-40 p-4 bg-white rounded-xl shadow-sm flex flex-col gap-1');
    N(Card, 'text-sm text-slate-500', STAT_DATA[I, 0]);
    N(Card, 'text-2xl font-bold ' + STAT_DATA[I, 2], STAT_DATA[I, 1]);
  end;
  Table := N(Main, 'bg-white rounded-xl border border-slate-200 overflow-hidden');
  Row := N(Table, 'flex px-4 py-2 bg-slate-50 border-b border-slate-200 text-xs font-semibold text-slate-500');
  N(Row, 'w-24', 'ORDER');
  N(Row, 'grow', 'CUSTOMER');
  N(Row, 'w-24 text-right', 'TOTAL');
  for I := 1 to 4 do begin
    Row := N(Table, 'flex px-4 py-2 border-b border-slate-100 last:border-b-0 text-sm text-slate-700 even:bg-slate-50 hover:bg-indigo-50');
    N(Row, 'w-24 font-mono', '#10' + IntToStr(I));
    N(Row, 'grow', 'Customer ' + IntToStr(I));
    N(Row, 'w-24 text-right', IntToStr(I * 37) + ' EUR');
  end;
end;

procedure BuildStyleSheet(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
var
  Menu: THtmlNode;
  I: Integer;
begin
  // classic CSS with selectors can be combined with utility classes
  AStyleSheet.Style :=
    '#body { padding: 24px; background-color: #fafafa }' +
    '.menu { display: flex; gap: 4px; padding: 4px; background-color: #e5e7eb; border-radius: 10px }' +
    '.menu > .item { padding: 6px 14px; border-radius: 8px; color: #374151; cursor: pointer }' +
    '.menu > .item:hover { background-color: #f9fafb }' +
    '.menu > .item.active { background-color: white; color: #111827; font-weight: bold }' +
    '.panel { margin-top: 16px; padding: 16px; border: 1px solid #d1d5db; border-radius: 8px; background-color: white }' +
    '.panel .title { font-size: 18px; font-weight: 600; margin-bottom: 8px }' +
    '.panel .item { padding: 8px 0; border-top: 1px solid #f3f4f6 }' +
    '.panel .item:last-child { color: #4f46e5 }';
  ABody.Id := 'body';
  ABody.ApplyStyle;
  Menu := N(ABody, 'menu');
  for I := 1 to 4 do
    if I = 1 then N(Menu, 'item active', 'Tab ' + IntToStr(I)) else N(Menu, 'item', 'Tab ' + IntToStr(I));
  Menu := N(ABody, 'panel');
  N(Menu, 'title', 'Stylesheet selectors');
  N(Menu, 'item', '.menu > .item:hover');
  N(Menu, 'item', '.panel .item');
  N(Menu, 'item', '.panel .item:last-child');
end;

procedure BuildBorders(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  STYLES: array[0..32] of String = (
    'border: 2px dashed #94a3b8; border-radius: 12px; background-color: #f8fafc',
    'border: 1px dashed #64748b',
    'border: 4px dashed #6366f1; border-radius: 20px',
    'border: 3px dotted #0ea5e9; border-radius: 16px',
    'border: 2px dotted #ef4444',
    'border-bottom: 3px dotted #22c55e; border-top: 3px dashed #f97316',
    'border-radius: 20px; border-top: 10px solid #ef4444',
    'border-radius: 20px; border-top: 10px solid #ef4444; border-left: 4px solid #22c55e',
    'border-radius: 24px; border: 6px solid; border-color: #ef4444 #22c55e #3b82f6 #eab308',
    'border-radius: 30px 4px; border: 3px solid #0f172a',
    'border-radius: 0 20px 40px 10px; border: 8px solid #6366f1',
    'border-radius: 6px; border: 12px solid #0ea5e9',
    'border-top-left-radius: 50px 15px; border-bottom-right-radius: 15px 50px; border: 2px solid #f97316',
    'border-radius: 9999px; border: 4px solid #a855f7',
    'border-radius: 50%; border: 10px solid #14b8a6',
    'border: 10px solid; border-color: #ef4444 #22c55e #3b82f6 #eab308',
    'border-left: 16px solid #ec4899; border-radius: 12px',
    'border-bottom: 6px solid #64748b; border-radius: 0 0 16px 16px',
    'border-radius: 16px; background-image: linear-gradient(to right, #6366f1, #ec4899)',
    'border-radius: 16px; background-image: linear-gradient(135deg, #22c55e, #3b82f6 60%, #a855f7); border: 3px solid #1e293b',
    'border-radius: 16px; background-color: rgba(99, 102, 241, 0.25); border: 2px solid rgba(99, 102, 241, 0.6)',
    'border-radius: 16px; background-image: linear-gradient(to bottom, #f59e0b, transparent)',
    'border-radius: 8px; border-top-left-radius: 24px; border-top-right-radius: 30px; border: 6px solid; border-color: #ef4444 #22c55e #3b82f6 #eab308; border-top: 20px dotted red; border-right:34px dotted blue;',
    'border-radius: 20px; border: 10px dotted #8b5cf6; border-left: 4px dashed #f97316; border-bottom: 12px solid #0ea5e9',
    // rare combinations: different widths, styles and radii on every side
    'border-radius: 40px 8px; border-style: solid; border-width: 2px 14px 6px 24px; border-color: #0f172a #f43f5e #22c55e #6366f1',
    'border-radius: 45px; border-top: 2px solid #0ea5e9; border-right: 18px dashed #f97316; border-bottom: 6px dotted #22c55e; border-left: 30px solid #6366f1',
    'border-radius: 60px 0; border-left: 20px dashed #ec4899; border-bottom: 20px dashed #14b8a6',
    'border-radius: 12px 50px; border: 1px solid #94a3b8; border-top: 16px solid #0f172a',
    'border-radius: 50%; border: 3px solid #94a3b8; border-top: 14px dotted #ef4444; border-bottom: 14px dotted #3b82f6',
    'border-radius: 30px; border-style: dashed solid solid dashed; border-width: 0 0 24px 24px; border-color: #a855f7 #000 #eab308 #22c55e',
    'border-top-right-radius: 70px 30px; border-bottom-left-radius: 70px 30px; border: 5px dashed #0ea5e9; border-right-width: 1px',
    'border-radius: 9999px; border: 8px dashed #f59e0b; border-top-color: transparent',
    'border-left: 40px solid #f43f5e; border-top: 4px dotted #0f172a; border-right: 2px dashed #0f172a; border-bottom-right-radius: 36px'
  );
var
  I: Integer;
  Grid: THtmlNode;
begin
  ABody.SetClass('p-6 bg-slate-50');
  Grid := N(ABody, 'flex flex-wrap gap-6');
  for I := 0 to High(STYLES) do
    HTMLDiv('width: 140px; height: 90px; background-color: #e2e8f0; ' + STYLES[I]).AppendTo(Grid);
end;

(*
  Generated image for background demo (no image files are needed)
*)
procedure RegisterDemoImage;
var
  Bmp: TBitmap;
  X, Y: Integer;
  F: Double;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(160, 100);
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do begin
        F := 0.5 + 0.5 * Sin(X / 9) * Cos(Y / 7);
        if Y > 60 + 10 * Sin(X / 15) then         // hills
          Bmp.Canvas.Pixels[X, Y] := RGBToColor(30 + Round(40 * F), 120 + Round(60 * F), 60)
        else                                       // sky
          Bmp.Canvas.Pixels[X, Y] := RGBToColor(120 + Y, 170 + Y div 2, 250);
      end;
    Bmp.Canvas.Brush.Color := RGBToColor(253, 224, 71);
    Bmp.Canvas.Pen.Color := RGBToColor(253, 224, 71);
    Bmp.Canvas.Ellipse(115, 12, 141, 38);          // sun
    CSSRegisterImage('demo-landscape', Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure BuildBackgrounds(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
var
  Row, Hero, Glass, Card: THtmlNode;
begin
  RegisterDemoImage;
  ABody.SetClass('p-6 bg-white flex flex-col gap-6');
  Row := N(ABody, 'flex flex-wrap gap-4');
  N(Row, 'grow basis-32 h-24 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 text-white font-bold flex items-center justify-center', 'to-r');
  N(Row, 'grow basis-32 h-24 rounded-xl bg-gradient-to-br from-fuchsia-500 via-purple-500 to-indigo-500 text-white font-bold flex items-center justify-center', 'to-br via');
  N(Row, 'grow basis-32 h-24 rounded-xl bg-gradient-to-t from-amber-500 text-amber-950 font-bold flex items-center justify-center border border-amber-200', 'from only');
  N(Row, 'grow basis-32 h-24 rounded-full bg-gradient-to-r from-emerald-400 to-lime-300 text-emerald-950 font-bold flex items-center justify-center', 'rounded-full');

  Hero := N(ABody, 'relative h-56 rounded-2xl bg-[url(demo-landscape)] bg-cover bg-center flex items-end p-6');
  Glass := N(Hero, 'max-w-sm p-4 rounded-xl bg-white/30 border border-white/50 flex flex-col gap-1');
  N(Glass, 'text-lg font-semibold text-slate-900', 'bg-cover bg-center');
  N(Glass, 'text-sm text-slate-900/80', 'Glass card: bg-white/30 border-white/50 over background image');

  Row := N(ABody, 'flex flex-wrap gap-4');
  Card := N(Row, 'w-48 h-32 rounded-lg border border-slate-200 bg-slate-100 bg-[url(demo-landscape)] bg-contain bg-center bg-no-repeat');
  N(Card, 'text-xs text-slate-500 p-1', 'bg-contain no-repeat');
  Card := N(Row, 'w-48 h-32 rounded-lg border border-slate-200 bg-[url(demo-landscape)] bg-[length:60px_40px]');
  N(Card, 'text-xs text-white p-1 font-bold', 'repeat 60x40');
  Card := N(Row, 'w-48 h-32 rounded-lg bg-slate-900 flex items-center justify-center');
  N(Card, 'px-3 py-1 rounded-full bg-white/10 text-white/80 border border-white/20 text-sm', 'bg-white/10');
end;

procedure BuildShadows(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  SHADOWS: array[0..5] of String = ('shadow-sm', 'shadow', 'shadow-md', 'shadow-lg', 'shadow-xl', 'shadow-2xl');
var
  I: Integer;
  Row: THtmlNode;
begin
  ABody.SetClass('p-8 bg-slate-100 flex flex-col gap-10');
  Row := N(ABody, 'flex flex-wrap gap-8');
  for I := 0 to High(SHADOWS) do
    N(Row, 'w-32 h-24 bg-white rounded-xl flex items-center justify-center text-sm font-mono text-slate-600 ' + SHADOWS[I], SHADOWS[I]);
  Row := N(ABody, 'flex flex-wrap gap-8 items-center');
  N(Row, 'px-5 py-3 rounded-lg bg-cyan-500 text-white font-semibold shadow-lg shadow-cyan-500/50', 'shadow-cyan-500/50');
  N(Row, 'px-5 py-3 rounded-lg bg-pink-500 text-white font-semibold shadow-xl shadow-pink-500/40', 'shadow-pink-500/40');
  N(Row, 'size-16 rounded-full bg-amber-400 shadow-lg shadow-amber-500/60');
  HTMLDiv('width: 120px; height: 60px; background-color: white; border-radius: 12px; box-shadow: 8px 8px 0 #0f172a').AppendTo(Row);
  HTMLDiv('width: 120px; height: 60px; background-color: white; border-radius: 12px; box-shadow: 0 0 0 4px #6366f1, 0 0 20px 6px rgba(99,102,241,0.5)').AppendTo(Row);
end;

(*
  Generated album cover for html demo
*)
procedure RegisterCoverImage;
var
  Bmp: TBitmap;
  X, Y, I: Integer;
  F: Double;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(192, 192);
    for Y := 0 to 191 do
      for X := 0 to 191 do begin
        F := (X + Y) / 382;
        Bmp.Canvas.Pixels[X, Y] := RGBToColor(Round(30 + 200 * F), Round(40 + 30 * (1 - F)), Round(120 + 100 * (1 - F)));
      end;
    Bmp.Canvas.Pen.Style := psClear;
    for I := 0 to 5 do begin
      Bmp.Canvas.Brush.Color := RGBToColor(255, 200 - I * 25, 80 + I * 20);
      Bmp.Canvas.Ellipse(30 + I * 18, 40 + I * 12, 110 + I * 18, 120 + I * 12);
    end;
    Bmp.Canvas.Brush.Style := bsClear;
    Bmp.Canvas.Font.Color := clWhite;
    Bmp.Canvas.Font.Size := 20;
    Bmp.Canvas.Font.Style := [fsBold];
    Bmp.Canvas.TextOut(14, 150, 'CLASS WARFARE');
    CSSRegisterImage('/img/cover.png', Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure BuildHtml(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
begin
  RegisterCoverImage;
  ABody.SetClass('p-8 bg-slate-100 flex flex-col gap-8');
  // example from tailwindcss.com
  ABody.AppendHTML(
    '<div class="flex flex-col items-center p-7 rounded-2xl bg-white shadow-lg max-w-md mx-auto">' +
    '  <div>' +
    '    <img class="size-48 shadow-xl rounded-md" alt="" src="/img/cover.png" />' +
    '  </div>' +
    '  <div class="flex flex-col items-center mt-6">' +
    '    <span class="text-2xl font-medium">Class Warfare</span>' +
    '    <span class="font-medium text-sky-500">The Anti-Patterns</span>' +
    '    <span class="flex gap-2 font-medium text-gray-600">' +
    '      <span>No. 4</span>' +
    '      <span>&middot;</span>' +
    '      <span>2025</span>' +
    '    </span>' +
    '  </div>' +
    '</div>');
  // notification list
  ABody.AppendHTML(
    '<div class="max-w-md mx-auto w-full bg-white rounded-xl shadow-md overflow-hidden">' +
    '  <div class="px-5 py-3 border-b border-slate-100 flex justify-between items-center">' +
    '    <b class="text-slate-900">Notifications</b>' +
    '    <span class="px-2 py-0.5 rounded-full bg-rose-500 text-white text-xs font-bold">3</span>' +
    '  </div>' +
    '  <div class="flex gap-3 px-5 py-3 hover:bg-slate-50 cursor-pointer">' +
    '    <div class="size-9 shrink-0 rounded-full bg-gradient-to-br from-sky-400 to-indigo-500"></div>' +
    '    <div class="flex flex-col"><span><b>Anna</b> commented on your design</span><span class="text-xs text-slate-500">2 minutes ago</span></div>' +
    '  </div>' +
    '  <div class="flex gap-3 px-5 py-3 hover:bg-slate-50 cursor-pointer">' +
    '    <div class="size-9 shrink-0 rounded-full bg-gradient-to-br from-amber-400 to-rose-500"></div>' +
    '    <div class="flex flex-col"><span><b>Peter</b> shared <i>Dashboard.fig</i></span><span class="text-xs text-slate-500">1 hour ago</span></div>' +
    '  </div>' +
    '</div>');
end;

procedure BuildTransforms(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
begin
  RegisterCoverImage;
  ABody.SetClass('p-8 bg-white flex flex-col gap-12');
  ABody.AppendHTML(
    // rotated photos
    '<div class="flex justify-center gap-6 pt-6">' +
    '  <div class="p-2 pb-6 bg-white shadow-lg -rotate-6"><img class="size-32" src="/img/cover.png"></div>' +
    '  <div class="p-2 pb-6 bg-white shadow-xl rotate-3 translate-y-2"><img class="size-32" src="/img/cover.png"></div>' +
    '  <div class="p-2 pb-6 bg-white shadow-lg rotate-12"><img class="size-32" src="/img/cover.png"></div>' +
    '</div>' +
    // hover effects
    '<div class="flex flex-wrap justify-center gap-6">' +
    '  <div class="w-40 p-4 rounded-xl bg-indigo-500 text-white font-semibold shadow-md hover:scale-110 cursor-pointer">hover:scale-110</div>' +
    '  <div class="w-40 p-4 rounded-xl bg-emerald-500 text-white font-semibold shadow-md hover:-rotate-3 cursor-pointer">hover:-rotate-3</div>' +
    '  <div class="w-40 p-4 rounded-xl bg-amber-500 text-white font-semibold shadow-md hover:-translate-y-2 hover:shadow-xl cursor-pointer">hover:-translate-y-2</div>' +
    '</div>' +
    // badge and centering
    '<div class="flex justify-center gap-10 items-center">' +
    '  <div class="relative w-48 h-24 rounded-xl border-2 border-dashed border-slate-300">' +
    '    <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 px-3 py-1 rounded-full bg-slate-900 text-white text-sm">centered</div>' +
    '    <div class="absolute top-0 right-0 translate-x-1/2 -translate-y-1/2 size-6 rounded-full bg-rose-500 text-white text-xs font-bold flex items-center justify-center">9</div>' +
    '  </div>' +
    '  <div class="px-4 py-2 bg-yellow-300 font-bold -skew-x-12">skew-x</div>' +
    '  <div class="size-16 rounded-lg bg-gradient-to-br from-pink-500 to-violet-600 rotate-45 shadow-lg"></div>' +
    '  <div class="px-3 py-1 rounded bg-sky-500 text-white origin-top-left rotate-12">origin</div>' +
    '</div>' +
    '<div class="flex justify-center gap-16 items-center py-4">' +
    '  <div class="px-3 py-1 rounded-md border border-slate-300 text-slate-700">scale 1</div>' +
    '  <div class="px-3 py-1 rounded-md border border-slate-300 text-slate-700 scale-150">scale-150</div>' +
    '  <div class="px-3 py-1 rounded-md border border-slate-300 text-slate-700 scale-[2]">scale-[2]</div>' +
    '</div>');
end;

procedure BuildDropzone(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
begin
  ABody.SetClass('p-8 bg-slate-50 flex flex-col gap-6');
  ABody.AppendHTML(
    '<div class="max-w-lg mx-auto w-full flex flex-col items-center justify-center gap-3 p-10 rounded-2xl ' +
    '  border-2 border-dashed border-slate-300 bg-white hover:border-indigo-400 hover:bg-indigo-50 cursor-pointer">' +
    '  <div class="size-14 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 text-2xl font-bold">&uarr;</div>' +
    '  <div><b class="text-indigo-600">Click to upload</b> <span class="text-slate-600">or drag and drop</span></div>' +
    '  <div class="text-xs text-slate-400">PNG, JPG or GIF (max. 10 MB)</div>' +
    '</div>' +
    '<div class="max-w-lg mx-auto w-full flex flex-col gap-3">' +
    '  <div class="flex items-center gap-3 p-3 rounded-xl bg-white border border-slate-200">' +
    '    <div class="size-10 rounded-lg bg-sky-100 text-sky-600 text-xs font-bold flex items-center justify-center">PNG</div>' +
    '    <div class="grow flex flex-col gap-1">' +
    '      <div class="flex justify-between text-sm"><span class="font-medium text-slate-800">design.png</span><span class="text-slate-500">72 %</span></div>' +
    '      <div class="h-2 rounded-full bg-slate-100"><div class="h-2 w-[72%] rounded-full bg-sky-500"></div></div>' +
    '    </div>' +
    '  </div>' +
    '  <div class="flex items-center gap-3 p-3 rounded-xl bg-white border border-slate-200">' +
    '    <div class="size-10 rounded-lg bg-emerald-100 text-emerald-600 text-xs font-bold flex items-center justify-center">JPG</div>' +
    '    <div class="grow flex flex-col gap-1">' +
    '      <div class="flex justify-between text-sm"><span class="font-medium text-slate-800">photo.jpg</span><span class="text-emerald-600">&check; done</span></div>' +
    '      <div class="h-2 rounded-full bg-emerald-500"></div>' +
    '    </div>' +
    '  </div>' +
    '</div>' +
    '<div class="max-w-lg mx-auto w-full p-4 rounded-xl border-2 border-dotted border-amber-400 bg-amber-50 text-amber-800 text-sm">' +
    '  Dotted border: <code>border-2 border-dotted</code>' +
    '</div>');
end;

(*
  Generated wallpaper pattern for chat demo
*)
procedure RegisterChatPattern;
var
  Bmp: TBitmap;
  I, X, Y: Integer;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(120, 120);
    Bmp.Canvas.Brush.Color := RGBToColor($EF, $EA, $E2);
    Bmp.Canvas.FillRect(0, 0, 120, 120);
    Bmp.Canvas.Pen.Color := RGBToColor($E2, $DC, $D2);
    Bmp.Canvas.Pen.Width := 2;
    Bmp.Canvas.Brush.Style := bsClear;
    RandSeed := 7;
    for I := 1 to 9 do begin
      X := Random(110);
      Y := Random(110);
      case I mod 3 of
        0: Bmp.Canvas.Ellipse(X, Y, X + 14, Y + 14);
        1: Bmp.Canvas.Rectangle(X, Y, X + 12, Y + 12);
        2: begin Bmp.Canvas.MoveTo(X, Y + 10); Bmp.Canvas.LineTo(X + 6, Y); Bmp.Canvas.LineTo(X + 12, Y + 10); end;
      end;
    end;
    CSSRegisterImage('demo-chat-pattern', Bmp);
  finally
    Bmp.Free;
  end;
end;

function Avatar(const AInitials, AGradient: String; const ASize: String = 'size-12'): String;
begin
  Result := '<div class="' + ASize + ' shrink-0 rounded-full bg-gradient-to-br ' + AGradient +
    ' text-white font-semibold flex items-center justify-center">' + AInitials + '</div>';
end;

function ChatItem(const AAvatar, AName, AMessage, ATime: String; AActive: Boolean = False; const AExtra: String = ''): String;
var
  Cls: String;
begin
  if AActive then Cls := 'bg-slate-100' else Cls := 'hover:bg-slate-50';
  Result :=
    '<div class="flex items-center gap-3 px-3 py-3 rounded-2xl cursor-pointer ' + Cls + '">' + AAvatar +
    '  <div class="grow min-w-0 flex flex-col gap-0.5 border-b border-slate-100 pb-2">' +
    '    <div class="flex items-center gap-2"><span class="grow truncate font-semibold text-slate-900">' + AName + '</span>' +
    '      <span class="text-xs text-slate-500">' + ATime + '</span></div>' +
    '    <div class="flex items-center gap-1 text-sm text-slate-500">' + AExtra + '<span class="truncate">' + AMessage + '</span></div>' +
    '  </div>' +
    '</div>';
end;

function NavItem(const AIcon, AText: String; AActive: Boolean = False; const ABadge: String = ''): String;
var
  Cls: String;
begin
  if AActive then Cls := 'bg-slate-200 font-semibold' else Cls := 'hover:bg-slate-200';
  Result := '<div class="flex items-center gap-3 px-3 py-2 rounded-xl cursor-pointer text-slate-800 ' + Cls + '">' +
    '<div class="w-6 flex items-center justify-center text-slate-700">' + AIcon + '</div><span class="grow">' + AText + '</span>';
  if ABadge <> '' then Result := Result + '<span class="text-sm text-slate-500">' + ABadge + '</span>';
  Result := Result + '</div>';
end;

(*
  Messaging app UI built with utility classes (fictional names)
*)
procedure BuildChatApp(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  ICON_CHAT = '<div class="w-5 h-4 rounded-full border-2 border-slate-700"></div>';
  ICON_UPDATES = '<div class="relative size-5 rounded-full border-2 border-dashed border-slate-700">' +
    '<div class="absolute -top-1 -right-1 size-2 rounded-full bg-green-500"></div></div>';
  ICON_COMMUNITY = '<div class="flex -space-x-1 gap-0.5"><div class="size-2.5 rounded-full border-2 border-slate-700"></div>' +
    '<div class="size-2.5 rounded-full border-2 border-slate-700"></div><div class="size-2.5 rounded-full border-2 border-slate-700"></div></div>';
  ICON_CALLS = '<span class="text-lg">&#9742;</span>';
  ICON_MEDIA = '<div class="w-5 h-4 rounded border-2 border-slate-700 flex items-end p-px"><div class="w-2 h-1 bg-slate-700 rounded-sm"></div></div>';
  ICON_STAR = '<span class="text-lg">&#9734;</span>';
begin
  RegisterChatPattern;
  ABody.SetClass('bg-white');
  ABody.AppendHTML(
    '<div class="flex h-full min-h-[420px] text-slate-900">' +
    // navigation
    '<div class="hidden md:flex w-52 shrink-0 flex-col gap-1 p-3 bg-slate-50 border-r border-slate-200">' +
      NavItem(ICON_CHAT, 'Chats', True) + NavItem(ICON_UPDATES, 'Updates') + NavItem(ICON_COMMUNITY, 'Communities') +
      NavItem(ICON_CALLS, 'Calls', False, '2') + NavItem(ICON_MEDIA, 'Media') +
    '  <div class="flex items-center justify-between px-3 pt-6 pb-2 text-xs font-semibold text-slate-400"><span>MORE</span><span>&#9662;</span></div>' +
      NavItem(ICON_STAR, 'Starred') +
    '  <div class="grow"></div>' +
    '  <div class="flex items-center gap-3 px-2 py-2 rounded-xl hover:bg-slate-200 cursor-pointer">' +
         Avatar('Y', 'from-amber-300 to-orange-400', 'size-9') +
    '    <span class="grow font-semibold">You</span><span class="text-slate-400">&#9998;</span>' +
    '  </div>' +
    '</div>' +
    // chat list
    '<div class="w-72 shrink-0 flex flex-col min-h-0 border-r border-slate-200">' +
    '  <div class="relative z-10 flex items-center justify-between px-4 h-16 shrink-0">' +
         Tooltip('<div class="size-10 rounded-full border border-slate-200 shadow-sm flex items-center justify-center font-bold text-slate-600 hover:bg-slate-50 cursor-pointer">&middot;&middot;&middot;</div>',
           'Menu', 'bottom') +
    '    <span class="text-lg font-semibold">Chats</span>' +
         Tooltip('<div class="size-11 rounded-full bg-green-600 hover:bg-green-700 shadow-md shadow-green-600/40 text-white text-2xl flex items-center justify-center cursor-pointer">+</div>',
           'New chat', 'bottom') +
    '  </div>' +
    '  <div class="mx-4 mb-3 flex items-center gap-3 px-4 py-2.5 rounded-full border border-slate-200 bg-slate-50">' +
    '    <div class="relative size-4"><div class="size-3 rounded-full border-2 border-slate-400"></div>' +
    '      <div class="absolute bottom-0 right-0 w-1.5 h-0.5 bg-slate-400 rotate-45"></div></div>' +
    '    <span class="text-slate-400">Search</span>' +
    '  </div>' +
    '  <div class="grow min-h-0 flex flex-col px-2 overflow-y-auto">' +
      ChatItem(Avatar('DT', 'from-violet-400 to-indigo-500'), 'Design Team 2026', '<i class="text-green-600">Liam is typing...</i>', '09:58', True) +
      ChatItem(Avatar('SB', 'from-pink-400 to-rose-500'), 'Sophia Bennett', 'Sounds great, see you there!', 'Yesterday') +
      ChatItem(Avatar('EC', 'from-sky-400 to-blue-500'), 'Emma Carter', 'You reacted to "Look, it still works"', 'Yesterday') +
      ChatItem(Avatar('NF', 'from-emerald-400 to-teal-500'), 'Noah Fischer', 'Okay', 'Thursday') +
      ChatItem(Avatar('OB', 'from-amber-400 to-orange-500'), 'Olivia Brooks', '<span class="text-rose-500">Missed video call</span>', 'Thursday', False,
        '<div class="w-3.5 h-2.5 rounded-sm bg-rose-500"></div>') +
      ChatItem(Avatar('LM', 'from-cyan-400 to-sky-500'), 'Lucas Meyer', 'Not the same. I do not censor anything', 'Wednesday', False,
        '<span class="text-sky-500 font-bold">&check;&check;</span>') +
      ChatItem(Avatar('MH', 'from-fuchsia-400 to-purple-500'), 'Mia Horvath', 'Good morning, no problem at all', 'Monday') +
      ChatItem(Avatar('JW', 'from-lime-400 to-green-500'), 'James Walker', 'Photo', 'Sunday') +
      ChatItem(Avatar('AK', 'from-orange-400 to-red-500'), 'Ava Kim', 'Thanks a lot!', 'Saturday') +
      ChatItem(Avatar('BT', 'from-slate-400 to-slate-600'), 'Build server', 'Release 2.4 deployed', '10/01/26') +
      ChatItem(Avatar('HR', 'from-teal-400 to-cyan-500'), 'Henry Ross', 'Let us talk on Monday', '09/29/26') +
    '  </div>' +
    '</div>' +
    // conversation
    '<div class="grow min-w-0 flex flex-col bg-[url(demo-chat-pattern)]">' +
    '  <div class="relative z-10 flex items-center gap-3 px-4 h-16 shrink-0 bg-white/90 border-b border-slate-200">' +
         Avatar('DT', 'from-violet-400 to-indigo-500', 'size-10') +
    '    <div class="grow min-w-0 flex flex-col"><span class="font-semibold truncate">Design Team 2026</span><span class="text-xs text-slate-500">3 online</span></div>' +
         Tooltip('<div class="flex items-center gap-1 px-3 py-1.5 rounded-full border border-slate-200 bg-white hover:bg-slate-50 cursor-pointer">' +
           '<div class="w-5 h-3.5 rounded border-2 border-slate-600"></div><span class="text-xs text-slate-600">&#9662;</span></div>', 'Video call', 'bottom') +
         Tooltip('<div class="px-2 font-bold text-slate-600 cursor-pointer">&middot;&middot;&middot;</div>', 'Group info', 'left') +
    '  </div>' +
    '  <div class="grow min-h-0 overflow-y-auto flex flex-col justify-end gap-3 px-6 py-4">' +
    '    <div class="self-center px-3 py-1 rounded-lg bg-white/80 text-xs text-slate-500 shadow-sm">YESTERDAY</div>' +
    '    <div class="flex justify-end"><div class="max-w-md px-3 py-2 bg-[#d9fdd3] rounded-2xl rounded-br-sm shadow-sm">Is everyone coming to the workshop?</div></div>' +
    '    <div class="flex items-end gap-2">' + Avatar('SB', 'from-pink-400 to-rose-500', 'size-8') +
    '      <div class="max-w-md flex flex-col px-3 py-2 bg-white rounded-2xl rounded-bl-sm shadow-sm"><span class="text-sm font-semibold text-pink-600">Sophia Bennett</span>' +
    '      <span>Yes, I will be there at nine.</span></div></div>' +
    '    <div class="flex items-end gap-2">' + Avatar('NF', 'from-emerald-400 to-teal-500', 'size-8') +
    '      <div class="max-w-md flex flex-col px-3 py-2 bg-white rounded-2xl rounded-bl-sm shadow-sm"><span class="text-sm font-semibold text-emerald-600">Noah Fischer</span>' +
    '      <span>Me too. Who brings the projector?</span></div></div>' +
    '    <div class="self-center px-3 py-1 rounded-lg bg-white/80 text-xs text-slate-500 shadow-sm">TODAY</div>' +
    // message with quote
    '    <div class="flex items-end gap-2">' + Avatar('EC', 'from-sky-400 to-blue-500', 'size-8') +
    '      <div class="max-w-md flex flex-col gap-1.5 px-3 py-2 bg-white rounded-2xl rounded-bl-sm shadow-sm">' +
    '        <span class="text-sm font-semibold text-teal-700">Emma Carter</span>' +
    '        <div class="flex flex-col px-3 py-2 rounded-lg bg-slate-100 border-l-4 border-rose-500">' +
    '          <div class="flex justify-between gap-4 text-sm"><b class="text-rose-600">Liam Novak</b><span class="text-slate-400">+1 555 0142</span></div>' +
    '          <span class="text-sm text-slate-600">He does not live in the city anymore</span>' +
    '        </div>' +
    '        <span>Were you a police officer? So we actually know each other! Officers used to come to our town festival.</span>' +
    '        <span class="self-end text-[11px] text-slate-400">09:49</span>' +
    '      </div>' +
    '    </div>' +
    // message with reaction
    '    <div class="flex items-end gap-2 pb-3">' + Avatar('LN', 'from-rose-400 to-red-500', 'size-8') +
    '      <div class="relative min-w-0 max-w-md flex flex-col gap-1.5 px-3 py-2 bg-white rounded-2xl rounded-bl-sm shadow-sm">' +
    '        <span class="text-sm font-semibold text-rose-600">Liam Novak</span>' +
    '        <div class="flex flex-col px-3 py-2 rounded-lg bg-slate-100 border-l-4 border-teal-600">' +
    '          <b class="text-sm text-teal-700">Emma Carter</b>' +
    '          <span class="text-sm text-slate-600 truncate">Were you a police officer? So we actually know each other!</span>' +
    '        </div>' +
    '        <div class="flex items-end gap-6"><span>Not me, that was my brother</span><span class="text-[11px] text-slate-400">09:52</span></div>' +
    '        <div class="absolute bottom-0 left-4 translate-y-1/2 px-1.5 rounded-full bg-white shadow border border-slate-100 text-sm text-rose-500">&#9829; 2</div>' +
    '      </div>' +
    '    </div>' +
    // own message
    '    <div class="flex justify-end">' +
    '      <div class="max-w-md flex flex-col gap-1 px-3 py-2 bg-[#d9fdd3] rounded-2xl rounded-br-sm shadow-sm">' +
    '        <span>Great, I will bring the slides tomorrow.</span>' +
    '        <div class="self-end flex items-center gap-1 text-[11px] text-slate-500">09:53 <span class="text-sky-500 font-bold">&check;&check;</span></div>' +
    '      </div>' +
    '    </div>' +
    // last message
    '    <div class="flex items-end gap-2">' + Avatar('EC', 'from-sky-400 to-blue-500', 'size-8') +
    '      <div class="max-w-md flex flex-col gap-1 px-3 py-2 bg-white rounded-2xl rounded-bl-sm shadow-sm">' +
    '        <span class="text-sm font-semibold text-teal-700">Emma Carter</span>' +
    '        <span>Perfect, then you can also take care of the rest &#128588;</span>' +
    '        <span class="self-end text-[11px] text-slate-400">09:54</span>' +
    '      </div>' +
    '    </div>' +
    '  </div>' +
    // composer
    '  <div class="flex items-center gap-3 px-4 py-3 shrink-0 bg-slate-50 border-t border-slate-200">' +
         Tooltip('<div class="size-11 shrink-0 rounded-full border border-slate-200 bg-white text-2xl text-slate-600 flex items-center justify-center hover:bg-slate-100 cursor-pointer">+</div>',
           'Attach photo or file', 'top') +
    '    <div class="grow flex items-center px-4 h-11 rounded-full bg-white border border-slate-200">' +
    '      <span class="grow text-slate-400">Type a message</span><span class="text-xl text-slate-500">&#9786;</span></div>' +
         Tooltip('<div class="size-11 shrink-0 rounded-full bg-green-600 hover:bg-green-700 shadow-md text-white flex items-center justify-center cursor-pointer">' +
           '<div class="flex flex-col items-center"><div class="w-2.5 h-3.5 rounded-full bg-white"></div>' +
           '<div class="w-4 h-2 -mt-1 rounded-b-full border-2 border-t-0 border-white"></div><div class="w-0.5 h-1 bg-white"></div></div></div>',
           'Voice message', 'left') +
    '  </div>' +
    '</div>' +
    '</div>');
end;

(*
  Input with label, wrapper (rounded border, shadow, focus ring) and LCL control placeholder.
  data-lcl nodes are replaced by LCL controls in demo application (TEdit, TMemo), the placeholder text
  is shown by PNG renderer. data-lcl="select" is a dropdown painted by renderer, items are shown in popup menu.
*)
const
  INPUT_WRAP = 'flex items-center gap-2 px-3 rounded-xl border border-slate-300 bg-white shadow-sm ' +
    'focus-within:border-indigo-500 focus-within:ring-4 focus-within:ring-indigo-100';

function Field(const ALabel, AInner: String; const AHint: String = ''; ARequired: Boolean = False; const AError: String = ''): String;
begin
  Result := '<div class="flex flex-col gap-1.5">' +
    '<div class="flex gap-1 text-sm font-medium text-slate-700"><span>' + ALabel + '</span>';
  if ARequired then Result := Result + '<span class="text-rose-500">*</span>';
  Result := Result + '</div>' + AInner;
  if AError <> '' then
    Result := Result + '<div class="flex items-center gap-1.5 text-xs text-rose-600">' +
      '<div class="size-4 rounded-full bg-rose-500 text-white text-[10px] font-bold flex items-center justify-center">!</div>' + AError + '</div>'
  else if AHint <> '' then
    Result := Result + '<div class="text-xs text-slate-500">' + AHint + '</div>';
  Result := Result + '</div>';
end;

function Edit(const APlaceholder: String; const AExtra: String = ''): String;
begin
  Result := '<div class="grow text-slate-400" data-lcl="edit" placeholder="' + APlaceholder + '"' + AExtra + '>' + APlaceholder + '</div>';
end;

(*
  Animated switch: class is-on (toggled by demo application) moves the knob with translate and transition.
  Scene must add SWITCH_CSS to its stylesheet (rule for knob depends on class of parent).
*)
const
  SWITCH_CSS = '.switch.is-on { background-color: #4f46e5 } .switch.is-on > .knob { translate: 20px 0 } ';

function Switch(AOn: Boolean): String;
const
  CLS = 'switch w-11 h-6 shrink-0 p-0.5 rounded-full bg-slate-300 transition-colors duration-200 cursor-pointer';
begin
  if AOn then
    Result := '<div class="' + CLS + ' is-on" data-active="is-on" data-checked="1">'
  else
    Result := '<div class="' + CLS + '" data-active="is-on">';
  Result := Result + '<div class="knob size-5 rounded-full bg-white shadow transition-transform duration-200 ease-out"></div></div>';
end;

function Checkbox(const AText: String; AChecked: Boolean): String;
const
  ON_CLS = 'bg-indigo-600 border-indigo-600 text-white';
var
  Cls: String;
begin
  Cls := 'size-5 shrink-0 rounded-md border-2 border-slate-300 bg-white text-transparent text-xs font-bold flex items-center justify-center cursor-pointer';
  if AChecked then
    Result := '<div class="flex items-center gap-2"><div class="' + Cls + ' ' + ON_CLS + '" data-active="' + ON_CLS + '" data-checked="1">&check;</div>'
  else
    Result := '<div class="flex items-center gap-2"><div class="' + Cls + '" data-active="' + ON_CLS + '">&check;</div>';
  Result := Result + '<span class="text-sm text-slate-700">' + AText + '</span></div>';
end;

(*
  Inputs: LCL controls inside of styled nodes
*)
procedure BuildForms(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
begin
  AStyleSheet.Style := AStyleSheet.Style + SWITCH_CSS;
  ABody.SetClass('p-8 bg-slate-50');
  ABody.AppendHTML(
    '<div class="max-w-2xl mx-auto flex flex-col gap-6">' +
    '  <div class="flex flex-col gap-1"><span class="text-2xl font-bold text-slate-900">Inputs</span>' +
    '    <span class="text-slate-500">Lazarus controls (TEdit, TMemo) inside of nodes styled with utility classes, dropdown with popup menu</span></div>' +
    '  <div class="flex flex-col gap-5 p-6 bg-white rounded-2xl shadow-md">' +
    '    <div class="flex flex-wrap gap-5">' +
    '      <div class="grow basis-56">' + Field('First name', '<div class="h-11 ' + INPUT_WRAP + '">' + Edit('Jane') + '</div>', '', True) + '</div>' +
    '      <div class="grow basis-56">' + Field('Last name', '<div class="h-11 ' + INPUT_WRAP + '">' + Edit('Doe') + '</div>', '', True) + '</div>' +
    '    </div>' +
    Field('E-mail', '<div class="h-11 ' + INPUT_WRAP + '"><span class="text-slate-400">@</span>' + Edit('name@example.com') + '</div>',
      'We never share your e-mail address.', True) +
    Field('Website', '<div class="h-11 flex items-stretch rounded-xl border border-slate-300 bg-white shadow-sm overflow-hidden ' +
      'focus-within:border-indigo-500 focus-within:ring-4 focus-within:ring-indigo-100">' +
      '<div class="flex items-center px-3 bg-slate-100 border-r border-slate-300 text-sm text-slate-500">https://</div>' +
      '<div class="grow flex items-center px-3">' + Edit('www.example.com') + '</div></div>') +
    Field('Password', '<div class="h-11 ' + INPUT_WRAP + '">' + Edit('Password', ' data-password="1" id="pwd"') +
      '<div class="px-2 py-1 rounded-md text-sm font-medium text-indigo-600 hover:bg-indigo-50 cursor-pointer" data-action="toggle-password">Show</div></div>',
      'At least 8 characters.', True) +
    // phone is validated while typing in demo application (TEdit.OnChange changes classes of wrapper)
    Field('Phone', '<div class="h-11 flex items-center gap-2 px-3 rounded-xl border border-rose-400 bg-white shadow-sm ' +
      'focus-within:ring-4 focus-within:ring-rose-100 transition-colors">' + Edit('+1 555 0100', ' id="phone"') + '</div>', '', False, 'Phone number is not valid.') +
    Field('Country', '<div class="h-11 ' + INPUT_WRAP + ' hover:border-slate-400 cursor-pointer" data-lcl="select" ' +
      'data-items="Slovakia|Czech Republic|Austria|Germany|Poland"><span class="grow text-slate-700">Slovakia</span>' +
      '<div class="size-2 -mt-1 mr-1 border-r-2 border-b-2 border-slate-400 rotate-45"></div></div>') +
    Field('Message', '<div class="h-28 py-2 ' + INPUT_WRAP + ' items-start"><div class="grow self-stretch text-slate-400" data-lcl="memo" ' +
      'placeholder="Write a few words...">Write a few words...</div></div>', 'Markdown is supported.') +
    '    <div class="flex items-center gap-2 h-12 pl-4 pr-1.5 rounded-full border border-slate-300 bg-white shadow-sm focus-within:ring-4 focus-within:ring-indigo-100">' +
    '      <div class="relative size-4 shrink-0"><div class="size-3 rounded-full border-2 border-slate-400"></div>' +
    '        <div class="absolute bottom-0 right-0 w-1.5 h-0.5 bg-slate-400 rotate-45"></div></div>' +
           Edit('Search with button inside') +
    '      <div class="px-4 py-2 rounded-full bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold cursor-pointer">Search</div>' +
    '    </div>' +
    '    <div class="flex flex-wrap gap-6">' + Checkbox('Remember me', True) + Checkbox('Send newsletter', False) +
    '      <div class="flex items-center gap-3">' + Switch(True) + '<span class="text-sm text-slate-700">Notifications</span></div></div>' +
    '    <div class="flex justify-end gap-3 pt-2 border-t border-slate-100">' +
    '      <div class="px-4 py-2 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50 cursor-pointer">Cancel</div>' +
    '      <div class="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 active:scale-95 text-white font-semibold shadow-md shadow-indigo-600/30 cursor-pointer" data-action="save">Save</div>' +
    '    </div>' +
    '  </div>' +
    '</div>');
end;

function SettingsRow(const ATitle, AText, AControl: String): String;
begin
  Result := '<div class="flex items-center gap-4 py-4 border-b border-slate-100 last:border-b-0">' +
    '<div class="grow min-w-0 flex flex-col"><span class="font-medium text-slate-900">' + ATitle + '</span>' +
    '<span class="text-sm text-slate-500">' + AText + '</span></div>' + AControl + '</div>';
end;

function ThemeCard(const AName, APreview: String; AChecked: Boolean): String;
const
  ON_CLS = 'border-indigo-500 ring-4 ring-indigo-100';
var
  Cls: String;
begin
  Cls := 'grow basis-32 flex flex-col gap-2 p-2 rounded-xl border-2 border-slate-200 cursor-pointer hover:border-slate-300';
  if AChecked then Cls := Cls + ' ' + ON_CLS;
  Result := '<div class="' + Cls + '" data-group="theme" data-active="' + ON_CLS + '"';
  if AChecked then Result := Result + ' data-checked="1"';
  Result := Result + '>' + APreview + '<span class="text-sm font-medium text-slate-700 px-1">' + AName + '</span></div>';
end;

(*
  Settings page
*)
procedure BuildSettings(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
const
  MENU_ON = 'bg-indigo-50 text-indigo-700 font-semibold';
  function MenuItem(const AText: String; AActive: Boolean): String;
  begin
    if AActive then
      Result := '<div class="px-3 py-2 rounded-lg cursor-pointer text-slate-600 hover:bg-slate-100 ' + MENU_ON + '" data-group="menu" data-active="' + MENU_ON + '" data-checked="1">' + AText + '</div>'
    else
      Result := '<div class="px-3 py-2 rounded-lg cursor-pointer text-slate-600 hover:bg-slate-100" data-group="menu" data-active="' + MENU_ON + '">' + AText + '</div>';
  end;
begin
  RegisterCoverImage;
  AStyleSheet.Style := AStyleSheet.Style + SWITCH_CSS;
  ABody.SetClass('bg-slate-50');
  ABody.AppendHTML(
    '<div class="flex h-full min-h-[420px]">' +
    '  <div class="hidden md:flex w-56 shrink-0 flex-col gap-1 p-4 border-r border-slate-200 bg-white">' +
    '    <span class="px-3 pb-3 text-lg font-bold text-slate-900">Settings</span>' +
         MenuItem('Account', True) + MenuItem('Notifications', False) + MenuItem('Appearance', False) +
         MenuItem('Privacy', False) + MenuItem('Billing', False) +
    '  </div>' +
    '  <div class="grow min-w-0 overflow-y-auto">' +
    '    <div class="max-w-2xl mx-auto p-8 flex flex-col gap-6">' +
    // profile
    '      <div class="p-6 bg-white rounded-2xl shadow-sm border border-slate-200 flex flex-col gap-5">' +
    '        <div class="flex flex-col"><span class="text-lg font-semibold text-slate-900">Profile</span>' +
    '          <span class="text-sm text-slate-500">This information is visible to your team.</span></div>' +
    // relative z-10: tooltips below buttons are painted over next rows
    '        <div class="relative z-10 flex items-center gap-4">' +
    '          <img class="size-16 rounded-full object-cover ring-4 ring-slate-100" src="/img/cover.png">' +
             Tooltip('<div class="px-3 py-1.5 rounded-lg border border-slate-300 text-sm font-medium text-slate-700 hover:bg-slate-50 cursor-pointer">Change</div>',
               'Upload a photo &middot; JPG or PNG, max. 2 MB', 'bottom') +
             Tooltip('<div class="px-3 py-1.5 rounded-lg text-sm font-medium text-rose-600 hover:bg-rose-50 cursor-pointer">Remove</div>',
               'Use initials instead of photo', 'bottom') +
    '        </div>' +
    '        <div class="flex flex-wrap gap-4">' +
    '          <div class="grow basis-56">' + Field('Name', '<div class="h-10 ' + INPUT_WRAP + '">' + Edit('Jane Doe') + '</div>', '', True) + '</div>' +
    '          <div class="grow basis-56">' + Field('E-mail', '<div class="h-10 ' + INPUT_WRAP + '">' + Edit('jane@example.com') + '</div>', '', True) + '</div>' +
    '        </div>' +
    // notifications
    '      </div>' +
    '      <div class="px-6 py-2 bg-white rounded-2xl shadow-sm border border-slate-200 flex flex-col">' +
    '        <span class="pt-4 text-lg font-semibold text-slate-900">Notifications</span>' +
           SettingsRow('Comments', 'Notify me when someone comments on my post.', Switch(True)) +
           SettingsRow('Mentions', 'Notify me when someone mentions me.', Switch(True)) +
           SettingsRow('Weekly summary', 'A short e-mail with activity of your team.', Switch(False)) +
    '      </div>' +
    // appearance
    '      <div class="p-6 bg-white rounded-2xl shadow-sm border border-slate-200 flex flex-col gap-4">' +
    '        <span class="text-lg font-semibold text-slate-900">Appearance</span>' +
    '        <div class="flex flex-wrap gap-4">' +
           ThemeCard('Light', '<div class="h-20 rounded-lg bg-slate-100 p-2 flex gap-1.5"><div class="w-6 rounded bg-white"></div>' +
             '<div class="grow flex flex-col gap-1.5"><div class="h-3 rounded bg-white"></div><div class="h-3 w-2/3 rounded bg-white"></div></div></div>', True) +
           ThemeCard('Dark', '<div class="h-20 rounded-lg bg-slate-800 p-2 flex gap-1.5"><div class="w-6 rounded bg-slate-600"></div>' +
             '<div class="grow flex flex-col gap-1.5"><div class="h-3 rounded bg-slate-600"></div><div class="h-3 w-2/3 rounded bg-slate-600"></div></div></div>', False) +
           ThemeCard('System', '<div class="h-20 rounded-lg bg-gradient-to-r from-slate-100 to-slate-800 p-2 flex gap-1.5"><div class="w-6 rounded bg-white/70"></div>' +
             '<div class="grow flex flex-col gap-1.5"><div class="h-3 rounded bg-white/50"></div><div class="h-3 w-2/3 rounded bg-white/50"></div></div></div>', False) +
    '        </div>' +
    '      </div>' +
    // danger zone
    '      <div class="p-6 rounded-2xl border border-rose-200 bg-rose-50 flex flex-wrap items-center gap-4">' +
    '        <div class="grow flex flex-col"><span class="font-semibold text-rose-700">Delete account</span>' +
    '          <span class="text-sm text-rose-600/80">All your data will be removed. This cannot be undone.</span></div>' +
    '        <div class="px-4 py-2 rounded-lg bg-rose-600 hover:bg-rose-700 text-white font-semibold shadow-sm cursor-pointer">Delete</div>' +
    '      </div>' +
    '    </div>' +
    '  </div>' +
    '</div>');
end;

(*
  Product "photos" drawn with nodes (no image files), neutral tones
*)
function ProductArt(AKind: Integer): String;
begin
  case AKind of
    0: Result := '<div class="flex flex-col items-center"><div class="w-24 h-12 rounded-t-full bg-stone-300"></div>' +      // table lamp
      '<div class="w-1.5 h-16 bg-stone-500"></div><div class="w-16 h-2.5 rounded-full bg-stone-600"></div></div>';
    1: Result := '<div class="flex flex-col items-center"><div class="w-20 h-10 rounded-t-full bg-[#e7dccb]"></div>' +      // floor lamp
      '<div class="w-1 h-36 bg-stone-700"></div><div class="w-14 h-2 rounded-full bg-stone-700"></div></div>';
    2: Result := '<div class="flex flex-col items-center self-start"><div class="w-0.5 h-20 bg-stone-400"></div>' +         // pendant
      '<div class="w-28 h-14 rounded-t-full bg-stone-800"></div><div class="w-10 h-3 rounded-b-full bg-amber-100"></div></div>';
    3: Result := '<div class="flex items-end gap-3"><div class="flex flex-col items-center"><div class="w-7 h-8 rounded-t-lg bg-[#d6cfc4]"></div>' +   // vases
      '<div class="w-20 h-24 -mt-2 rounded-full bg-[#d6cfc4]"></div></div><div class="w-12 h-16 rounded-t-3xl rounded-b-xl bg-stone-400"></div></div>';
    4: Result := '<div class="flex flex-col items-center gap-1"><div class="size-24 rounded-full bg-stone-100 border-[10px] border-stone-300"></div>' +   // wall light
      '<div class="w-6 h-2 rounded-full bg-stone-400"></div></div>';
    5: Result := '<div class="w-36 h-12 rounded-b-full bg-stone-400"></div>';                                              // bowl
  else
    Result := '<div class="flex flex-col items-center"><div class="w-32 h-3 rounded-full bg-[#b9a58a]"></div>' +           // side table
      '<div class="flex justify-between w-24"><div class="w-1.5 h-24 bg-stone-600"></div><div class="w-1.5 h-24 bg-stone-600"></div></div></div>';
  end;
end;

function ProductCard(AKind: Integer; const AName, AInfo, APrice, ABadge: String): String;
begin
  Result :=
    '<div class="group flex flex-col gap-3 cursor-pointer">' +
    '  <div class="relative h-64 rounded-2xl bg-gradient-to-b from-stone-100 to-stone-200/70 flex items-end justify-center pb-10 overflow-hidden">' +
         ProductArt(AKind);
  if ABadge <> '' then
    Result := Result + '<div class="absolute top-3 left-3 px-2.5 py-1 rounded-full bg-white text-[11px] font-medium text-stone-700">' + ABadge + '</div>';
  Result := Result +
    '    <div class="absolute bottom-3 left-3 right-3 hidden group-hover:flex justify-center py-2.5 rounded-xl bg-white/90 text-sm font-medium text-stone-900 shadow-sm">Quick add</div>' +
    '  </div>' +
    '  <div class="flex items-start justify-between gap-3">' +
    '    <div class="flex flex-col gap-0.5 min-w-0"><span class="text-sm font-medium text-stone-900 truncate group-hover:underline">' + AName + '</span>' +
    '      <span class="text-sm text-stone-500 truncate">' + AInfo + '</span></div>' +
    '    <span class="text-sm font-medium text-stone-900">' + APrice + '</span>' +
    '  </div>' +
    '</div>';
end;

(*
  E-shop: product grid (layout first, neutral colors)
*)
procedure BuildShop(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  function Chip(const AText: String; AOn: Boolean): String;
  const
    ON_CLS = 'bg-stone-900 border-stone-900 text-white';
  var
    Cls: String;
  begin
    Cls := 'px-4 py-1.5 rounded-full border border-stone-200 text-sm text-stone-700 hover:border-stone-400 cursor-pointer';
    if AOn then
      Result := '<div class="' + Cls + ' ' + ON_CLS + '" data-group="chip" data-active="' + ON_CLS + '" data-checked="1">' + AText + '</div>'
    else
      Result := '<div class="' + Cls + '" data-group="chip" data-active="' + ON_CLS + '">' + AText + '</div>';
  end;
begin
  ABody.SetClass('bg-white');
  ABody.AppendHTML(
    '<div class="flex flex-col h-full min-h-[420px]">' +
    // header
    '  <div class="flex items-center gap-8 px-8 h-16 shrink-0 border-b border-stone-200">' +
    '    <span class="text-xl font-semibold text-stone-900">lumen</span>' +
    '    <div class="hidden md:flex gap-6 text-sm text-stone-500"><span class="text-stone-900 font-medium">Lighting</span>' +
    '      <span class="hover:text-stone-900 cursor-pointer">Furniture</span><span class="hover:text-stone-900 cursor-pointer">Decor</span>' +
    '      <span class="hover:text-stone-900 cursor-pointer">Journal</span></div>' +
    '    <div class="grow"></div>' +
    '    <div class="hidden sm:flex w-56 items-center gap-2 h-9 px-3.5 rounded-full bg-stone-100 focus-within:bg-white focus-within:ring-2 focus-within:ring-stone-900">' +
    '      <div class="relative size-4 shrink-0"><div class="size-3 rounded-full border-2 border-stone-400"></div>' +
    '        <div class="absolute bottom-0 right-0 w-1.5 h-0.5 bg-stone-400 rotate-45"></div></div>' + Edit('Search') + '</div>' +
    '    <span class="text-sm font-medium text-stone-900 cursor-pointer">Cart (2)</span>' +
    '  </div>' +
    // content
    '  <div class="grow min-h-0 overflow-y-auto">' +
    '    <div class="max-w-6xl mx-auto px-8 py-8 flex flex-col gap-6">' +
    '      <span class="text-xs text-stone-400">Home &nbsp;/&nbsp; Lighting</span>' +
    '      <div class="flex items-end justify-between gap-4">' +
    '        <div class="flex flex-col gap-1"><span class="text-3xl font-semibold text-stone-900">Lighting</span>' +
    '          <span class="text-sm text-stone-500">Lamps and objects for calm, warm interiors &middot; 48 products</span></div>' +
    '        <span class="text-sm text-stone-700 cursor-pointer">Sort: Popular &darr;</span>' +
    '      </div>' +
    '      <div class="flex flex-wrap gap-2">' + Chip('All', True) + Chip('Table lamps', False) + Chip('Floor lamps', False) +
             Chip('Pendants', False) + Chip('Wall lights', False) + Chip('Vases', False) + '</div>' +
    '      <div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-x-6 gap-y-10 pt-2">' +
             ProductCard(0, 'Orbit table lamp', 'Linen &middot; Oak', '89 EUR', 'New') +
             ProductCard(1, 'Arc floor lamp', 'Brushed steel', '219 EUR', '') +
             ProductCard(2, 'Dome pendant', 'Matte black', '149 EUR', 'Bestseller') +
    '        <div class="col-span-2 md:col-span-1 xl:col-span-1 flex flex-col justify-end gap-3 p-8 rounded-2xl bg-stone-900 text-white cursor-pointer">' +
    '          <span class="text-xs font-medium text-stone-400">NEW SEASON</span>' +
    '          <span class="text-2xl font-semibold">Warm light for long evenings</span>' +
    '          <span class="text-sm text-stone-300 group-hover:underline">Explore the collection &rarr;</span></div>' +
             ProductCard(3, 'Pebble vase set', 'Stoneware, 2 pcs', '39 EUR', '') +
             ProductCard(4, 'Halo wall light', 'Opal glass', '119 EUR', 'New') +
             ProductCard(5, 'Shell bowl', 'Travertine', '59 EUR', '') +
             ProductCard(6, 'Nord side table', 'Solid oak', '189 EUR', '') +
    '      </div>' +
    '    </div>' +
    '  </div>' +
    '</div>');
end;

(*
  Month calendar
*)
procedure BuildCalendar(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  function Event(const AText, AColor: String): String;
  begin
    Result := '<div class="px-1.5 py-0.5 rounded-md text-xs font-medium truncate ' + AColor + '">' + AText + '</div>';
  end;
  function Cell(ADay: Integer; AOther, AToday: Boolean; const AEvents: String): String;
  var
    Num: String;
  begin
    if AToday then Num := '<div class="size-7 rounded-full bg-indigo-600 text-white text-sm font-semibold flex items-center justify-center">' + IntToStr(ADay) + '</div>'
    else if AOther then Num := '<div class="size-7 text-sm text-slate-300 flex items-center justify-center">' + IntToStr(ADay) + '</div>'
    else Num := '<div class="size-7 text-sm text-slate-700 flex items-center justify-center">' + IntToStr(ADay) + '</div>';
    Result := '<div class="grow basis-0 min-w-0 flex flex-col gap-1 p-1.5 border-r border-b border-slate-200 last:border-r-0 hover:bg-slate-50">' + Num + AEvents + '</div>';
  end;
var
  Grid, Ev: String;
  W, D, Day: Integer;
begin
  ABody.SetClass('bg-white');
  // October 2026 starts on Thursday: first week begins Monday September 28
  Grid := '';
  for W := 0 to 4 do begin
    Grid := Grid + '<div class="grow basis-0 min-h-[84px] flex">';
    for D := 0 to 6 do begin
      Day := W * 7 + D - 2;       // 1 = October 1
      Ev := '';
      case Day of
        1: Ev := Event('Sprint planning', 'bg-sky-100 text-sky-700');
        5: Ev := Event('Design review', 'bg-violet-100 text-violet-700');
        8: Ev := Event('Release 2.4', 'bg-emerald-100 text-emerald-700') + Event('Retro', 'bg-amber-100 text-amber-700');
        10: Ev := Event('Workshop 9:00', 'bg-rose-100 text-rose-700');
        14: Ev := Event('Customer call', 'bg-sky-100 text-sky-700');
        16: Ev := Event('Team lunch', 'bg-amber-100 text-amber-700');
        21: Ev := Event('Conference', 'bg-fuchsia-100 text-fuchsia-700') + Event('Talk: CSS in Pascal', 'bg-indigo-100 text-indigo-700');
        22: Ev := Event('Conference', 'bg-fuchsia-100 text-fuchsia-700');
        27: Ev := Event('Board meeting', 'bg-slate-200 text-slate-700');
        30: Ev := Event('Halloween party', 'bg-orange-100 text-orange-700');
      end;
      if Day < 1 then Grid := Grid + Cell(30 + Day, True, False, '')
      else if Day > 31 then Grid := Grid + Cell(Day - 31, True, False, '')
      else Grid := Grid + Cell(Day, False, Day = 10, Ev);
    end;
    Grid := Grid + '</div>';
  end;
  ABody.AppendHTML(
    '<div class="flex h-full min-h-[420px]">' +
    '  <div class="grow min-w-0 flex flex-col">' +
    '    <div class="flex flex-wrap items-center gap-3 px-6 py-4 border-b border-slate-200">' +
    '      <span class="text-xl font-bold text-slate-900">October 2026</span>' +
    '      <div class="flex rounded-lg border border-slate-300 overflow-hidden">' +
    '        <div class="px-2.5 py-1 hover:bg-slate-50 cursor-pointer text-slate-600">&lsaquo;</div>' +
    '        <div class="px-3 py-1 border-x border-slate-300 text-sm font-medium hover:bg-slate-50 cursor-pointer">Today</div>' +
    '        <div class="px-2.5 py-1 hover:bg-slate-50 cursor-pointer text-slate-600">&rsaquo;</div></div>' +
    '      <div class="grow"></div>' +
    '      <div class="flex p-1 rounded-lg bg-slate-100 text-sm">' +
    '        <span class="px-3 py-1 text-slate-600 cursor-pointer" data-group="view" data-active="bg-white shadow-sm text-slate-900 font-medium">Day</span>' +
    '        <span class="px-3 py-1 text-slate-600 cursor-pointer" data-group="view" data-active="bg-white shadow-sm text-slate-900 font-medium">Week</span>' +
    '        <span class="px-3 py-1 text-slate-600 cursor-pointer bg-white shadow-sm text-slate-900 font-medium" data-group="view" data-active="bg-white shadow-sm text-slate-900 font-medium" data-checked="1">Month</span></div>' +
    '      <div class="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold shadow-sm cursor-pointer">+ New event</div>' +
    '    </div>' +
    '    <div class="flex border-b border-slate-200 bg-slate-50">' +
    '      <div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">MON</div><div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">TUE</div>' +
    '      <div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">WED</div><div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">THU</div>' +
    '      <div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">FRI</div><div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">SAT</div>' +
    '      <div class="grow basis-0 py-2 text-center text-xs font-semibold text-slate-500">SUN</div></div>' +
    '    <div class="grow min-h-0 flex flex-col overflow-y-auto">' + Grid + '</div>' +
    '  </div>' +
    // upcoming
    '  <div class="hidden lg:flex w-72 shrink-0 flex-col gap-4 p-6 border-l border-slate-200 bg-slate-50 overflow-y-auto">' +
    '    <span class="font-semibold text-slate-900">Upcoming</span>' +
    '    <div class="flex flex-col gap-1 p-3 rounded-xl bg-white shadow-sm border-l-4 border-rose-500"><span class="text-sm font-semibold">Workshop</span>' +
    '      <span class="text-xs text-slate-500">Today, 9:00 - 12:00</span></div>' +
    '    <div class="flex flex-col gap-1 p-3 rounded-xl bg-white shadow-sm border-l-4 border-sky-500"><span class="text-sm font-semibold">Customer call</span>' +
    '      <span class="text-xs text-slate-500">Wed, Oct 14, 14:30</span></div>' +
    '    <div class="flex flex-col gap-1 p-3 rounded-xl bg-white shadow-sm border-l-4 border-amber-500"><span class="text-sm font-semibold">Team lunch</span>' +
    '      <span class="text-xs text-slate-500">Fri, Oct 16, 12:00</span></div>' +
    '    <div class="flex flex-col gap-1 p-3 rounded-xl bg-white shadow-sm border-l-4 border-fuchsia-500"><span class="text-sm font-semibold">Conference</span>' +
    '      <span class="text-xs text-slate-500">Oct 21 - 22</span></div>' +
    '  </div>' +
    '</div>');
end;

(*
  Grid layout: bento tiles (col-span, row-span) and label/value form
*)
procedure BuildGrid(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  // AMuted: color of small texts (color with alpha is cheaper than opacity, which is painted through bitmap)
  function Tile(const ACls, AMuted, ATitle, AValue, ANote: String): String;
  begin
    Result := '<div class="' + ACls + ' flex flex-col justify-between gap-2 p-5 rounded-2xl">' +
      '<span class="text-sm ' + AMuted + '">' + ATitle + '</span>' +
      '<span class="text-3xl font-semibold">' + AValue + '</span>' +
      '<span class="text-xs ' + AMuted + '">' + ANote + '</span></div>';
  end;
  function Row(const ALabel, AValue: String): String;
  begin
    Result := '<span class="text-sm text-slate-500">' + ALabel + '</span><span class="text-sm text-slate-900">' + AValue + '</span>';
  end;
begin
  ABody.SetClass('p-8 bg-slate-50');
  ABody.AppendHTML(
    '<div class="max-w-4xl mx-auto flex flex-col gap-8">' +
    '  <div class="flex flex-col gap-1"><span class="text-2xl font-bold text-slate-900">Grid</span>' +
    '    <span class="text-slate-500">grid-cols-*, col-span-*, row-span-*, gap-* and arbitrary tracks</span></div>' +
    '  <div class="grid grid-cols-2 md:grid-cols-4 gap-4">' +
         Tile('col-span-2 row-span-2 bg-slate-900 text-white', 'text-white/60', 'Revenue this year', '128 400 EUR',
           '+18 % compared to last year &middot; col-span-2 row-span-2') +
         Tile('bg-white border border-slate-200 text-slate-900', 'text-slate-500', 'Orders', '1 284', 'last 30 days') +
         Tile('bg-indigo-600 text-white', 'text-white/70', 'Customers', '642', '+32 this week') +
         Tile('col-span-2 bg-amber-100 text-amber-900', 'text-amber-900/70', 'Average order', '100 EUR', 'col-span-2') +
         Tile('bg-white border border-slate-200 text-slate-900', 'text-slate-500', 'Returns', '1.2 %', 'below target') +
         Tile('col-span-full md:col-span-3 bg-emerald-50 text-emerald-900', 'text-emerald-900/70', 'Stock', '98 % available', 'col-span-full md:col-span-3') +
    '  </div>' +
    '  <div class="grid grid-cols-[auto_1fr] gap-x-6 gap-y-3 items-center p-6 rounded-2xl bg-white border border-slate-200">' +
         Row('Name', 'Jane Doe') + Row('E-mail', 'jane@example.com') +
         Row('Plan', '<span class="px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700 text-xs font-medium">Pro</span>') +
         Row('Billing address', 'Main Street 12, 811 01 Bratislava') +
    '  </div>' +
    '  <div class="grid grid-cols-3 md:grid-cols-6 gap-3">' +
    '    <div class="h-16 rounded-xl bg-rose-200"></div><div class="h-16 rounded-xl bg-orange-200"></div><div class="h-16 rounded-xl bg-amber-200"></div>' +
    '    <div class="h-16 rounded-xl bg-lime-200"></div><div class="h-16 rounded-xl bg-teal-200"></div><div class="h-16 rounded-xl bg-sky-200"></div>' +
    '  </div>' +
    '</div>');
end;

(*
  Minimal animations: transitions on hover (colors, opacity, transform) and built-in animations
*)
procedure BuildAnimations(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  function Section(const ATitle: String): String;
  begin
    Result := '<span class="text-sm font-semibold text-slate-500 pt-2">' + ATitle + '</span>';
  end;
begin
  // animated switch: knob is moved by translate (stylesheet rule for parent class)
  AStyleSheet.Style := AStyleSheet.Style + SWITCH_CSS;
  ABody.SetClass('p-8 bg-white');
  ABody.AppendHTML(
    '<div class="max-w-3xl flex flex-col gap-5">' +
    '  <div class="flex flex-col gap-1"><span class="text-2xl font-bold text-slate-900">Animations</span>' +
    '    <span class="text-slate-500">transition, duration-*, ease-*, opacity-*, animate-spin / ping / pulse / bounce</span></div>' +
       Section('Transitions (hover)') +
    '  <div class="flex flex-wrap items-center gap-4">' +
    '    <div class="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-emerald-500 text-white font-semibold transition duration-300 cursor-pointer">Color</div>' +
    '    <div class="px-4 py-2 rounded-lg border-2 border-slate-300 hover:border-indigo-500 text-slate-700 hover:text-indigo-600 transition-colors duration-300 cursor-pointer">Outline</div>' +
    '    <div class="size-12 rounded-xl bg-amber-400 hover:scale-125 hover:rotate-12 transition-transform duration-300 ease-out cursor-pointer"></div>' +
    '    <div class="px-4 py-2 rounded-lg bg-slate-900 text-white opacity-50 hover:opacity-100 transition-opacity duration-500 cursor-pointer">Fade in</div>' +
         Switch(False) +
    '  </div>' +
    '  <div class="flex flex-wrap gap-4">' +
    '    <div class="w-52 flex flex-col gap-2 p-4 rounded-xl bg-white border border-slate-200 shadow-sm hover:shadow-lg hover:-translate-y-1.5 transition duration-300 cursor-pointer">' +
    '      <span class="font-semibold text-slate-900">Lift on hover</span><span class="text-sm text-slate-500">translate with transition</span></div>' +
    '    <div class="group relative w-52 flex flex-col gap-2 p-4 rounded-xl bg-slate-900 text-white cursor-pointer">' +
    '      <span class="font-semibold">Reveal on hover</span><span class="text-sm text-slate-400">group-hover: opacity</span>' +
    '      <div class="absolute top-3 right-3 px-2 py-0.5 rounded-full bg-emerald-400 text-slate-900 text-xs font-bold opacity-0 group-hover:opacity-100 transition-opacity duration-300">NEW</div></div>' +
    '  </div>' +
       Section('Animations') +
    '  <div class="flex flex-wrap items-center gap-8">' +
    '    <div class="flex items-center gap-3"><div class="size-8 rounded-full border-4 border-indigo-100 border-t-indigo-600 animate-spin"></div>' +
    '      <span class="text-sm text-slate-600">animate-spin</span></div>' +
    '    <div class="flex items-center gap-3"><div class="relative size-3"><div class="absolute inset-0 rounded-full bg-sky-400 animate-ping"></div>' +
    '      <div class="absolute inset-0 rounded-full bg-sky-500"></div></div><span class="text-sm text-slate-600">animate-ping</span></div>' +
    '    <div class="flex items-center gap-3"><div class="size-9 rounded-full bg-white border border-slate-200 shadow flex items-center justify-center text-indigo-600 animate-bounce">&darr;</div>' +
    '      <span class="text-sm text-slate-600">animate-bounce</span></div>' +
    '    <div class="flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-600 text-white text-sm font-semibold">' +
    '      <div class="size-4 rounded-full border-2 border-white/30 border-t-white animate-spin"></div>Processing...</div>' +
    '  </div>' +
    '  <div class="flex gap-4 p-4 w-full max-w-md rounded-xl border border-slate-200 animate-pulse">' +
    '    <div class="size-12 shrink-0 rounded-full bg-slate-200"></div>' +
    '    <div class="grow flex flex-col gap-2 pt-1"><div class="h-3 w-3/4 rounded bg-slate-200"></div>' +
    '      <div class="h-3 rounded bg-slate-200"></div><div class="h-3 w-1/2 rounded bg-slate-200"></div></div>' +
    '  </div>' +
    '  <span class="text-xs text-slate-400">animate-pulse (loading skeleton)</span>' +
    '</div>');
end;


end.
