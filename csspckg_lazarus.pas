{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit csspckg_lazarus;

{$warn 5023 off : no warning about unused units}
interface

uses
  CSSCtrls, cssbase, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('CSSCtrls', @CSSCtrls.Register);
end;

initialization
  RegisterPackage('csspckg_lazarus', @Register);
end.
