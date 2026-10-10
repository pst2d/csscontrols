(*
  Basic HTML markup for csscontrols: describe UI with html like in Tailwind CSS examples
  Author: Pavol Stugel (pstugel@gmail.com)

  Usage:
    uses cssbase, csshtml;
    CSSShape1.Body.AppendHTML(
      '<div class="flex items-center gap-4 p-6 rounded-xl shadow-lg">' +
      '  <img class="size-12 rounded-full" src="avatar.png">' +
      '  <div><b id="name">Erin</b> &middot; <span class="text-slate-500">online</span></div>' +
      '</div>');
    CSSShape1.Body.GetElementById('name').OnClick := @NameClick;
    CSSShape1.Changed;

  Only visual markup is supported (KISS): elements, attributes class, style, id (other attributes are
  available by Node.Attributes['name']), text, entities, <img src>, <br>, <style> (appended to stylesheet
  of root node if it is assigned). Scripts, forms, links and other browser behavior are not supported.
  Whitespace between inline elements is kept as one space (not in flex containers).
*)
unit csshtml;

{$ifdef fpc}
  {$mode objfpc}{$H+}
{$endif}

interface

uses
  Classes, SysUtils, cssbase;

type

  { TCSSHtmlNodeHelper }

  TCSSHtmlNodeHelper = class helper for THtmlNode
  public
    function AppendHTML(const AHtml: String): THtmlNode;   // parse html and append nodes as children, returns self
    procedure SetHTML(const AHtml: String);                // replace children
  end;

procedure CSSParseHTML(const AHtml: String; AParent: THtmlNode);
function CSSDecodeEntities(const AValue: String): String;

implementation

const
  VOID_ELEMENTS: array[0..9] of String = ('img', 'br', 'hr', 'input', 'meta', 'link', 'area', 'base', 'col', 'wbr');

  ENTITIES: array[0..19] of record N, V: String; end = (
    (N: 'amp'; V: '&'), (N: 'lt'; V: '<'), (N: 'gt'; V: '>'), (N: 'quot'; V: '"'), (N: 'apos'; V: ''''),
    (N: 'nbsp'; V: #$C2#$A0), (N: 'middot'; V: #$C2#$B7), (N: 'copy'; V: #$C2#$A9), (N: 'reg'; V: #$C2#$AE),
    (N: 'hellip'; V: #$E2#$80#$A6), (N: 'mdash'; V: #$E2#$80#$94), (N: 'ndash'; V: #$E2#$80#$93),
    (N: 'bull'; V: #$E2#$80#$A2), (N: 'times'; V: #$C3#$97), (N: 'euro'; V: #$E2#$82#$AC),
    (N: 'rarr'; V: #$E2#$86#$92), (N: 'larr'; V: #$E2#$86#$90), (N: 'uarr'; V: #$E2#$86#$91), (N: 'darr'; V: #$E2#$86#$93),
    (N: 'check'; V: #$E2#$9C#$93)
  );

function CodePointToUTF8(ACode: Cardinal): String;
begin
  case ACode of
    0..$7F: Result := Chr(ACode);
    $80..$7FF: Result := Chr($C0 or (ACode shr 6)) + Chr($80 or (ACode and $3F));
    $800..$FFFF: Result := Chr($E0 or (ACode shr 12)) + Chr($80 or ((ACode shr 6) and $3F)) + Chr($80 or (ACode and $3F));
    else Result := Chr($F0 or (ACode shr 18)) + Chr($80 or ((ACode shr 12) and $3F)) + Chr($80 or ((ACode shr 6) and $3F)) +
      Chr($80 or (ACode and $3F));
  end;
end;

(*
  &amp; &#183; &#xB7; and named entities from ENTITIES
*)
function CSSDecodeEntities(const AValue: String): String;
var
  I, P, K, Code: Integer;
  Name: String;
  Found: Boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(AValue) do begin
    if AValue[I] = '&' then begin
      P := I + 1;
      while (P <= Length(AValue)) and (P - I <= 10) and (AValue[P] <> ';') and (AValue[P] <> '&') and (AValue[P] <> ' ') do Inc(P);
      if (P <= Length(AValue)) and (AValue[P] = ';') then begin
        Name := Copy(AValue, I + 1, P - I - 1);
        Found := False;
        if (Name <> '') and (Name[1] = '#') then begin
          if (Length(Name) > 1) and (Name[2] in ['x', 'X']) then Found := TryStrToInt('$' + Copy(Name, 3, MaxInt), Code)
            else Found := TryStrToInt(Copy(Name, 2, MaxInt), Code);
          if Found and (Code > 0) then Result := Result + CodePointToUTF8(Code) else Found := False;
        end else
          for K := 0 to High(ENTITIES) do
            if ENTITIES[K].N = Name then begin
              Result := Result + ENTITIES[K].V;
              Found := True;
              Break;
            end;
        if Found then begin
          I := P + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + AValue[I];
    Inc(I);
  end;
end;

function CollapseWhitespace(const AValue: String): String;
var
  I: Integer;
  Space: Boolean;
begin
  Result := '';
  Space := False;
  for I := 1 to Length(AValue) do
    if AValue[I] in [' ', #9, #10, #13] then
      Space := True
    else begin
      if Space then Result := Result + ' ';
      Space := False;
      Result := Result + AValue[I];
    end;
  if Space then Result := Result + ' ';
end;

function IsVoid(const AName: String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(VOID_ELEMENTS) do
    if VOID_ELEMENTS[I] = AName then Exit(True);
  Result := False;
end;

(*
  Element with only one text child gets the text directly
*)
procedure FinishElement(ANode: THtmlNode);
var
  T: THtmlNode;
begin
  // trailing whitespace is removed
  T := ANode.FirstChild;
  while Assigned(T) and Assigned(ANode.GetNext(T)) do T := ANode.GetNext(T);
  if Assigned(T) and (T.Element = '#text') and (Trim(T.Text) = '') then ANode.Delete(T);
  T := ANode.FirstChild;
  if (ANode.ChildCount = 1) and (T.Element = '#text') and (ANode.Text = '') then begin
    ANode.Text := Trim(T.Text);
    ANode.Delete(T);
  end;
end;

procedure CSSParseHTML(const AHtml: String; AParent: THtmlNode);
var
  Stack: array of THtmlNode;
  I, P, Len: Integer;
  S, Name, AttrName, AttrValue: String;
  Node, Current: THtmlNode;
  Closing, SelfClosing: Boolean;
  Q: Char;
  procedure Push(ANode: THtmlNode);
  begin
    SetLength(Stack, Length(Stack) + 1);
    Stack[High(Stack)] := ANode;
  end;
  procedure AddText(const AText: String);
  var
    T: String;
    Last: THtmlNode;
  begin
    T := CollapseWhitespace(CSSDecodeEntities(AText));
    if Trim(T) = '' then begin
      // whitespace is kept only after inline element in inline content (not in flex container)
      Last := Current.FirstChild;
      while Assigned(Last) and Assigned(Current.GetNext(Last)) do Last := Current.GetNext(Last);
      if (Current.CompStyle.Display in [cdtFlex, cdtInlineFlex]) or not Assigned(Last) or
        not (Last.CompStyle.Display in [cdtInline, cdtInlineFlex]) then Exit;
      T := ' ';
    end;
    Node := THtmlNode.Create;
    Node.Element := '#text';
    Node.Text := T;
    Current.AddNode(Node);
  end;
  procedure SetNodeAttribute(ANode: THtmlNode; const AName, AValue: String);
  begin
    if AName = 'class' then ANode.ClassList.Name := AValue
    else if AName = 'style' then ANode.InlineStyle := AValue
    else if AName = 'id' then ANode.Id := AValue
    else ANode.SetAttribute(AName, AValue);
  end;
begin
  Len := Length(AHtml);
  Stack := nil;
  Current := AParent;
  I := 1;
  while I <= Len do begin
    if AHtml[I] <> '<' then begin
      P := I;
      while (I <= Len) and (AHtml[I] <> '<') do Inc(I);
      AddText(Copy(AHtml, P, I - P));
      Continue;
    end;
    // comments, doctype
    if Copy(AHtml, I, 4) = '<!--' then begin
      P := Pos('-->', Copy(AHtml, I + 4, MaxInt));
      if P = 0 then Break;
      I := I + 4 + P + 2;
      Continue;
    end;
    if (I < Len) and (AHtml[I + 1] in ['!', '?']) then begin
      while (I <= Len) and (AHtml[I] <> '>') do Inc(I);
      Inc(I);
      Continue;
    end;
    // tag
    Inc(I);
    Closing := (I <= Len) and (AHtml[I] = '/');
    if Closing then Inc(I);
    P := I;
    while (I <= Len) and not (AHtml[I] in [' ', #9, #10, #13, '>', '/']) do Inc(I);
    Name := LowerCase(Copy(AHtml, P, I - P));
    if Closing then begin
      while (I <= Len) and (AHtml[I] <> '>') do Inc(I);
      Inc(I);
      // close element and all unclosed elements inside it
      for P := High(Stack) downto 0 do
        if Stack[P].Element = Name then begin
          while High(Stack) >= P do begin
            FinishElement(Stack[High(Stack)]);
            SetLength(Stack, Length(Stack) - 1);
          end;
          Break;
        end;
      if Length(Stack) > 0 then Current := Stack[High(Stack)] else Current := AParent;
      Continue;
    end;
    if Name = '' then begin
      AddText('<');
      Continue;
    end;
    Node := THtmlNode.Create;
    Node.Element := Name;
    SelfClosing := False;
    // attributes
    repeat
      while (I <= Len) and (AHtml[I] in [' ', #9, #10, #13]) do Inc(I);
      if I > Len then Break;
      if AHtml[I] = '>' then begin
        Inc(I);
        Break;
      end;
      if AHtml[I] = '/' then begin
        SelfClosing := True;
        Inc(I);
        Continue;
      end;
      P := I;
      while (I <= Len) and not (AHtml[I] in [' ', #9, #10, #13, '=', '>', '/']) do Inc(I);
      AttrName := LowerCase(Copy(AHtml, P, I - P));
      AttrValue := '';
      while (I <= Len) and (AHtml[I] in [' ', #9, #10, #13]) do Inc(I);
      if (I <= Len) and (AHtml[I] = '=') then begin
        Inc(I);
        while (I <= Len) and (AHtml[I] in [' ', #9, #10, #13]) do Inc(I);
        if (I <= Len) and (AHtml[I] in ['"', '''']) then begin
          Q := AHtml[I];
          Inc(I);
          P := I;
          while (I <= Len) and (AHtml[I] <> Q) do Inc(I);
          AttrValue := Copy(AHtml, P, I - P);
          Inc(I);
        end else begin
          P := I;
          while (I <= Len) and not (AHtml[I] in [' ', #9, #10, #13, '>']) do Inc(I);
          AttrValue := Copy(AHtml, P, I - P);
        end;
      end;
      if AttrName <> '' then SetNodeAttribute(Node, AttrName, CSSDecodeEntities(AttrValue));
    until False;
    // <style> is appended to stylesheet, <script> is ignored
    if (Name = 'style') or (Name = 'script') then begin
      P := Pos('</' + Name, LowerCase(Copy(AHtml, I, MaxInt)));
      if P = 0 then P := Len - I + 2;
      S := Copy(AHtml, I, P - 1);
      if (Name = 'style') and Assigned(AParent.RootNode.StyleSheet) then AParent.RootNode.StyleSheet.Append(S);
      I := I + P - 1;
      while (I <= Len) and (AHtml[I] <> '>') do Inc(I);
      Inc(I);
      Node.Free;
      Continue;
    end;
    Current.AddNode(Node);
    Node.ApplyStyle;      // display of element is needed for whitespace handling
    if not (SelfClosing or IsVoid(Name)) then begin
      Push(Node);
      Current := Node;
    end;
  end;
  for P := High(Stack) downto 0 do FinishElement(Stack[P]);    // unclosed elements
end;

{ TCSSHtmlNodeHelper }

function TCSSHtmlNodeHelper.AppendHTML(const AHtml: String): THtmlNode;
begin
  Result := Self;
  CSSParseHTML(AHtml, Self);
  Changed;
end;

procedure TCSSHtmlNodeHelper.SetHTML(const AHtml: String);
begin
  Clear;
  AppendHTML(AHtml);
end;

end.
