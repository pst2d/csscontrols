(*
  Demo scenes for csscontrols, used by demo application and PNG renderer
*)
unit demoscenes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, cssbase;

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

const
  DEMO_SCENES: array[0..6] of TDemoScene = (
    (Name: 'Card'; Build: @BuildCard),
    (Name: 'Buttons'; Build: @BuildButtons),
    (Name: 'Flexbox'; Build: @BuildFlex),
    (Name: 'Responsive'; Build: @BuildResponsive),
    (Name: 'Typography'; Build: @BuildTypography),
    (Name: 'Dashboard'; Build: @BuildDashboard),
    (Name: 'Stylesheet'; Build: @BuildStyleSheet)
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
  Card := N(ABody, 'max-w-sm mx-auto flex items-center gap-4 p-6 bg-white rounded-xl border border-slate-200');
  N(Card, 'size-12 shrink-0 rounded-full bg-sky-500');
  Info := N(Card, 'flex flex-col gap-1');
  N(Info, 'text-xl font-medium text-black', 'ChitChat');
  N(Info, 'text-slate-500', 'You have a new message!');

  Card := N(ABody, 'max-w-sm mx-auto mt-6 p-6 bg-white rounded-2xl border border-slate-200 flex flex-col gap-4');
  Info := N(Card, 'flex items-center gap-3');
  N(Info, 'size-10 shrink-0 rounded-full bg-violet-500');
  N(Info, 'grow font-semibold text-slate-900', 'Erin Lindford');
  N(Info, 'px-2 py-1 text-xs font-semibold rounded-full bg-emerald-100 text-emerald-700', 'Online');
  N(Card, 'text-slate-600', 'Product engineer. Building user interfaces with utility classes in Lazarus.');
  Info := N(Card, 'flex gap-2 justify-end');
  N(Info, 'px-4 py-2 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-100 cursor-pointer', 'Message');
  N(Info, 'px-4 py-2 rounded-lg bg-violet-600 hover:bg-violet-700 active:bg-violet-800 text-white font-semibold cursor-pointer', 'Follow');
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
    Card := N(Stats, 'grow basis-40 p-4 bg-white rounded-xl border border-slate-200 flex flex-col gap-1');
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

end.
