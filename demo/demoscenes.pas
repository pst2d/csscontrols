(*
  Demo scenes for csscontrols, used by demo application and PNG renderer
*)
unit demoscenes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, cssbase;

type
  TBuildSceneProc = procedure(ABody: THtmlNode; AStyleSheet: TCSSStyleSheet);
  TDemoScene = record
    Name: String;
    Build: TBuildSceneProc;
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

const
  DEMO_SCENES: array[0..9] of TDemoScene = (
    (Name: 'Card'; Build: @BuildCard),
    (Name: 'Buttons'; Build: @BuildButtons),
    (Name: 'Flexbox'; Build: @BuildFlex),
    (Name: 'Responsive'; Build: @BuildResponsive),
    (Name: 'Typography'; Build: @BuildTypography),
    (Name: 'Dashboard'; Build: @BuildDashboard),
    (Name: 'Stylesheet'; Build: @BuildStyleSheet),
    (Name: 'Borders'; Build: @BuildBorders),
    (Name: 'Backgrounds'; Build: @BuildBackgrounds),
    (Name: 'Shadows'; Build: @BuildShadows)
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
  STYLES: array[0..15] of String = (
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
    'border-radius: 16px; background-image: linear-gradient(to bottom, #f59e0b, transparent)'
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

end.
