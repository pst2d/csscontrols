unit cssbutton;

(*
  Example of own Lazarus component built on TCSSShape: button with Caption and Kind properties.
  Look of the button is described with utility classes, painting and hover/active states are done by
  the engine. Use it as any other control: Btn := TCSSButton.Create(Self); Btn.Parent := Self; Btn.OnClick := ...
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, cssbase, CSSCtrls;

type
  TCSSButtonKind = (cbkPrimary, cbkSecondary, cbkDanger);

  { TCSSButton }

  TCSSButton = class(TCSSShape)
  private
    FCaption: String;
    FKind: TCSSButtonKind;
    FNode: THtmlNode;
    procedure SetCaption(const AValue: String);
    procedure SetKind(AValue: TCSSButtonKind);
    procedure UpdateNode;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: String read FCaption write SetCaption;
    property Kind: TCSSButtonKind read FKind write SetKind default cbkPrimary;
    property OnClick;
  end;

implementation

const
  BUTTON_BASE = 'h-full flex items-center justify-center px-4 rounded-lg text-sm font-semibold cursor-pointer transition ';
  BUTTON_KIND: array[TCSSButtonKind] of String = (
    'bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 text-white shadow-sm',
    'bg-white border border-slate-300 hover:bg-slate-50 active:bg-slate-100 text-slate-700',
    'bg-rose-600 hover:bg-rose-500 active:bg-rose-700 text-white shadow-sm');

constructor TCSSButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaption := 'Button';
  FNode := HTMLNode('').AppendTo(Body);
  Body.SetClass('h-full');
  UpdateNode;
end;

procedure TCSSButton.SetCaption(const AValue: String);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  UpdateNode;
end;

procedure TCSSButton.SetKind(AValue: TCSSButtonKind);
begin
  if FKind = AValue then Exit;
  FKind := AValue;
  UpdateNode;
end;

procedure TCSSButton.UpdateNode;
begin
  FNode.Text := FCaption;
  FNode.SetClass(BUTTON_BASE + BUTTON_KIND[FKind]);
  Body.ApplyStyles;
  Changed;
end;

end.
