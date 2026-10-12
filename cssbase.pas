(*
  Version 0.2
  Author: Pavol Stugel (pstugel@gmail.com)
  Warning: this is work in progress version, all methods can be changed in future!

  Scope:
  - very basic html(node) +  basic css layout support. KISS (https://en.wikipedia.org/wiki/KISS_principle)
  - Tailwind CSS like utility classes (see csstailwind.pas)

  TODO (in random order):
  - transition support
  - opacity, inset box-shadow, line-height
  - radial gradients, multiple backgrounds
  - display:grid
  - delphi support

  History:
  2026.10.10 - CSS engine rework: selectors and cascade, flexbox (direction, wrap, gap, grow/shrink/basis,
               justify-content, align-items/self, auto margins, order), box-sizing, min/max sizes, em/rem units,
               high dpi pixel ratio, float:right, font properties, text wrapping, full color table,
               utility classes support (csstailwind.pas), tests and demo
             - antialiased painting of rounded corners and border joins (cached corner bitmaps),
               linear-gradient, background images (url, size, position, repeat), colors with alpha,
               custom properties and var()
             - box-shadow (9-slice cached templates), native drawing of images and horizontal/vertical gradients,
               bitmaps in device resolution (Retina)
             - transform (translate, scale, rotate, skew, matrix, transform-origin, translate/rotate/scale properties),
               HitTest with inverse transformation, dashed and dotted borders, <img> element, element default styles,
               basic html markup (csshtml.pas)
             - scrolling (overflow auto/scroll, overlay scrollbars, mouse wheel, thumb dragging), z-index,
               :focus and :focus-within, automatic minimum height of flex items in column
  2020.05.01 - Align LCL controls working again
  2020.04.17 - TCSSShape fixes, "0" length fixed
  2020.02.22 - baseline align fix, added: display:inline-flex; basic owerflow support
  2019.12.18 - fixed layout, code reorganization
  2019.12.07 - added basic display:flex support, added position (absolute,relative,static) support, fixed bugs
  2019.12.03 - added support for border and border-radius, fixed vertical-align for baseline
  2019.11.21 - fixed font size calculation, added basic class support

*)

unit cssbase;

{$ifdef fpc}
  {$mode objfpc}{$H+}
  {$modeswitch advancedrecords}
{$else}
  {$define delphi}
  {$if declared(FireMonkeyVersion) AND (FireMonkeyVersion >= 1)}
    {$define fmx}
  {$endif}
  {$define fmx}
{$endif}

interface

uses
  Classes, SysUtils, Types,
  {$ifdef fpc}
  Controls,  Graphics, Forms, GraphType, IntfGraphics, FPImage,
  LCLIntf, LCLProc, LMessages, LCLType,  contnrs, LazCanvas,
  {$else}
  // delphi
  System.UITypes,
  FMX.Controls, FMX.Graphics,
  {$endif}
  Math;
const
  CSS_UNIVERSAL_SELECTOR: Char = '*';   //https://developer.mozilla.org/en-US/docs/Web/CSS/Universal_selectors
  CSS_DEBUG_MODE: Boolean = False;
  HTMLInterface = '{DD8167E4-D923-407A-AE4C-14BB93E254E3}';
  CSS_DEG_RAD = Pi / 180;
  CSS_DEFAULT_FONT_SIZE = 16;   // px, browser default font size
  CSS_UTILITY_ORDER_BASE = 100000000;       // utility classes are after stylesheet rules
  CSS_UTILITY_BREAKPOINT_ORDER = 1000000;   // responsive utilities (sm:, md: ...) are after base utilities
type
  TCSSBorderStyle = (cbsUndefined, cbsNone, cbsHidden, cbsDotted, cbsDashed, cbsSolid, cbsDouble, cbsGroove, cbsRidge, cbsInset, cbsOutset); // https://developer.mozilla.org/en-US/docs/Web/CSS/border-style
  TCSSFontStyle = (cfsUndefined, cfsNormal, cfsItalic, cfsOblique, cfsInherit, cfsUnset); // https://developer.mozilla.org/en-US/docs/Web/CSS/font-style
  TCSSFontWeightType = (cfwUndefined, cfwNormal, cfwBold, cfwLighter, cfwBolder, cfwInherit, cfwUnset); // https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight
  TCSSLengthType = (cltUndefined, cltPx, cltPt, cltAuto, cltEm, cltPercentage, cltRem);
  TCSSTextAlign = (ctaUndefined, ctaLeft, ctaRight, ctaCenter, ctaJustify);   // https://developer.mozilla.org/en-US/docs/Web/CSS/text-align
  TCSSColorType = (cctUndefined, cctNormal, cctTransparent, cctCurrentColor);
  TCSSTextDecoration = (ctdUndefined, ctdUnderline, ctdNone, ctdLineThrough);   // https://developer.mozilla.org/en-US/docs/Web/CSS/text-decoration
  TCSSDisplayType = (cdtBlock, cdtInline, cdtFlex, cdtInlineFlex, cdtNone, cdtGrid);         // https://developer.mozilla.org/en-US/docs/Web/CSS/display
  TCSSFloatType = (cftUndefined, cftNone, cftLeft, cftRight);        // https://developer.mozilla.org/en-US/docs/Web/CSS/float
  TCSSSide = (csTop, csLeft, csBottom, csRight);        // for margin, padding etc.
  TCSSFlexWrap = (cfwNoWrap, cfwWrap, cfwWrapReverse);  // https://developer.mozilla.org/en-US/docs/Web/CSS/flex-wrap
  TCSSFlexDirection = (cfdRow, cfdRowReverse, cfdColumn, cfdColumnReverse); // https://developer.mozilla.org/en-US/docs/Web/CSS/flex-direction
  TCSSPosition = (cpStatic, cpRelative, cpAbsolute, cpFixed, cpSticky); // https://developer.mozilla.org/en-US/docs/Web/CSS/position
  TCSSAlignItems = (caiStretch, caiBaseline, caiCenter, caiFlexStart, caiFlexEnd, caiAuto);  // https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Flexible_Box_Layout/Aligning_Items_in_a_Flex_Container
  TCSSJustifyContent = (cjcFlexStart, cjcFlexEnd, cjcCenter, cjcSpaceBetween, cjcSpaceAround, cjcSpaceEvenly); // https://developer.mozilla.org/en-US/docs/Web/CSS/justify-content
  TCSSOverflowType = (cotVisible, cotHidden, cotScroll, cotAuto);          // https://developer.mozilla.org/en-US/docs/Web/CSS/overflow
  TCSSBoxSizing = (cbxContentBox, cbxBorderBox);                          // https://developer.mozilla.org/en-US/docs/Web/CSS/box-sizing
  TCSSWhiteSpace = (cwsNormal, cwsNoWrap);                                // https://developer.mozilla.org/en-US/docs/Web/CSS/white-space
  // inherited properties explicitly set by style (others are inherited from parent node)
  TCSSInheritedProp = (cipColor, cipFontSize, cipFontFamily, cipFontStyle, cipFontWeight, cipTextDecoration, cipTextAlign, cipWhiteSpace);
  TCSSInheritedProps = set of TCSSInheritedProp;
  {$ifndef fpc}
  TStringArray = array of String;
  {$endif}
  TFloatPoint = record
    x,y: Single;
  end;
  TPointArray = array of TFloatPoint;
  TCSSLength = record      // https://developer.mozilla.org/en-US/docs/Web/CSS/length
    Value: Single;
    LengthType: TCSSLengthType;
  end;

  TCSSInteger = Integer;
  TCSSNumber = Single;
  TCSSMatrix = array [0..5] of Single;
	{ TMatrixTransform }
    {
		https://www.w3.org/TR/SVG/coords.html#NestedTransformations
		Base Affine Translation Matrix
		( M0  M2  M4 )
		( M1  M3  M5 )
		( 0    0   1 )
    }
	TMatrixTransform = class
  protected
		FData: TCSSMatrix;
	public
    constructor Create; overload; virtual;
    constructor Create(M0, M1, M2, M3, M4, M5: Single); overload;
    procedure Multiply(AMatrix: TMatrixTransform);
    function Setup(M0, M1, M2, M3, M4, M5: Single): TMatrixTransform;  inline;
    function Reset: TMatrixTransform;
    function FlipHorizontal: TMatrixTransform;
    function FlipVertical: TMatrixTransform;
    function Scale(AX, AY: Single): TMatrixTransform;
    function Skew(AX, AY: Single): TMatrixTransform;
    function Rotate(Angle: Single): TMatrixTransform;
    function Translate(AX, AY: Single): TMatrixTransform;
    procedure Transform(var P: TFloatPoint);
	end;

  TCSSColor = record
    Value: TColor;
    ColorType: TCSSColorType;
    Alpha: Byte;              // 255 = opaque
  end;

  TCSSBorder = record         // https://developer.mozilla.org/en-US/docs/Web/CSS/border
    Color: TCSSColor;
    Style: TCSSBorderStyle;
    Width: TCSSLength;
  end;

  TCSSBackground = record        // https://developer.mozilla.org/en-US/docs/Web/CSS/background
    Color: TCSSColor;
    Image: String;              // background-image: url(...) or linear-gradient(...), can contain var()
    Size: String;               // background-size: auto, cover, contain, <length> [<length>]
    Position: String;           // background-position
    RepeatMode: String;         // background-repeat: repeat (default), no-repeat
  end;

  TCSSBorderRadius = record       // https://developer.mozilla.org/en-US/docs/Web/CSS/border-radius
    Width,
    Height: TCSSLength;
  end;

  TCSSFontWeight = record
    FontType: TCSSFontWeightType;
    Value: TFontStyles;
  end;

  TCSSFont = record             // https://developer.mozilla.org/en-US/docs/Web/CSS/font
    Family: String;
    Size: TCSSLength;
    Style: TCSSFontStyle;
    Weight: TCSSFontWeight;
    TextDecoration: TCSSTextDecoration;        // TODO: maybe here is not right place
    CachedText: String;       // TODO: move this part away
    CachedWidth,
    CachedHeight,
    CachedBaseLine: Integer;
    CachedMinWidth: Integer;      // width of longest word
    CachedPixelRatio: Single;
  end;
  TCSSStyleSheet = class;

  TCSSPaintShape = record
    L, T, R, B: Single;                 // border box
    BW: array[TCSSSide] of Single;      // border widths
    RX, RY: array[0..3] of Single;      // corner radii: top-left, top-right, bottom-right, bottom-left
  end;

  TCSSPixel = packed record     // 32 bit BGRA pixel (not premultiplied)
    B, G, R, A: Byte;
  end;
  PCSSPixel = ^TCSSPixel;
  { TCSSImageData - decoded image for background-image }
  TCSSImageData = class
    Width, Height: Integer;
    Pixels: array of TCSSPixel;
    Premultiplied: array of LongWord;   // A shl 24 or R shl 16 or G shl 8 or B, color multiplied by alpha
    HasAlpha: Boolean;
    Bitmap: TBitmap;                    // for native drawing, created on first use
    destructor Destroy; override;
  end;

  TCSSRGBA = record
    R, G, B, A: Single;                 // 0..1, not premultiplied
  end;
  TCSSGradientStop = record
    Color: TCSSRGBA;
    Pos: Single;              // 0..1, -1 = not set
  end;
  TCSSGradient = record
    DirX, DirY: Single;       // direction of gradient line
    Stops: array of TCSSGradientStop;
  end;
  TCSSShadow = record
    X, Y, Blur, Spread: Integer;   // canvas pixels
    Color: TCSSColor;
    Inset: Boolean;
  end;
  TCSSShadowArray = array of TCSSShadow;

  TCSSMatrix2D = record          // affine transformation: x' = A*x + C*y + E, y' = B*x + D*y + F
    A, B, C, D, E, F: Single;
  end;
  TCSSTransformKind = (tkNone, tkTranslate, tkGeneral);
  TCSSTiming = record                    // cubic-bezier() timing function
    X1, Y1, X2, Y2: Single;
  end;
  TCSSColorChannels = array[0..5] of TCSSColor;
  TCSSRectArray = array of TRect;   // background, color, border top, right, bottom, left
  PCSSAnim = ^TCSSAnim;
  TCSSAnim = record                      // running transition and/or built-in animation of node
    Start: QWord;
    Duration, Delay: Integer;            // ms
    Timing: TCSSTiming;
    ColorOn: array[0..5] of Boolean;
    ColorFrom, ColorTo: TCSSColorChannels;
    OpacityOn: Boolean;
    OpacityFrom, OpacityTo, BaseOpacity: Single;
    MatrixOn, MatrixPending: Boolean;    // pending: target matrix is known after layout
    MatrixFrom, MatrixTo: TCSSMatrix2D;
    Frames: Integer;                     // built-in keyframes: 0 none, 1 spin, 2 ping, 3 pulse, 4 bounce
    FramesDuration: Integer;
    FramesStart: QWord;
  end;
  THtmlNode = class;
  TCSSLayoutKey = record         // input of LayoutGetNodeSize
    PW, PH, FW, FH: Integer;
    InFlex: Boolean;
  end;
  TCSSLayoutResult = record      // size of node for input (cached during one layout pass)
    Key: TCSSLayoutKey;
    Margin, Padding, Border, Position: TRect;
    BaseLine, ContentWidth, ContentHeight: Integer;
  end;
  TCSSLayoutState = record       // saved layout of node (transformed node is laid out again in higher resolution)
    Node: THtmlNode;
    ContentRect, MarginRect, Margin, Padding, Border, Position: TRect;
    BaseLine, ContentWidth, ContentHeight, LayoutWidth, LayoutHeight: Integer;
    FontSize: Single;
    Transform, TransformTarget: TCSSMatrix2D;
    Kind: TCSSTransformKind;
    Visible, LayoutRoot: Boolean;
  end;
  TCSSLayoutStates = array of TCSSLayoutState;



  TCSSCombinator = (ccNone, ccDescendant, ccChild);
  { TCSSCompoundSelector - one part of selector eg. "div.button:hover" }
  TCSSCompoundSelector = record
    Element: String;            // '' or '*' = any element
    Id: String;
    Classes: TStringArray;
    Pseudos: TStringArray;      // hover, active, first-child, last-child
    Combinator: TCSSCombinator; // relation to previous (left) compound
  end;
  TCSSCompoundSelectors = array of TCSSCompoundSelector;

  { TCSSItem }
  TCSSItem = class(TPersistent)
  public
    Attributes: String;
    AlignSelf,                  // default auto
    AlignItems: TCSSAlignItems;
    Background: TCSSBackground;
    BoxSizing: TCSSBoxSizing;
    BoxShadow: String;          // box-shadow, can contain var()
    ObjectFit,                  // img: fill (default), contain, cover, none, scale-down
    ObjectPosition: String;
    Transform,                  // transform functions, can contain var()
    TransformOrigin,
    Translate,                  // individual transform properties
    Rotate,
    Scale: String;
    Opacity: Single;            // 0..1, default 1
    PointerEventsNone: Boolean; // pointer-events: none (mouse ignores node and its children)
    TransitionProperty,         // all (default), none, list of properties
    TransitionTiming: String;   // ease, linear, ease-in, ease-out, ease-in-out, cubic-bezier()
    TransitionDuration,         // ms
    TransitionDelay: Integer;
    Animation: String;          // built-in animations: spin, ping, pulse, bounce (animation: spin 1s linear infinite)
    LineClamp: Integer;         // line-clamp: text is cut to N lines with ellipsis (0 = none)
    ScrollbarNone: Boolean;     // scrollbar-width: none (content can still be scrolled)
    AspectRatio: Single;        // aspect-ratio: width / height (0 = auto)
    Color: TCSSColor;
    Cursor: TCursor;
    Changed: Boolean;
    Display: TCSSDisplayType;
    Font: TCSSFont;
    Float: TCSSFloatType;
    FlexBasis: TCSSLength;      // default auto
    FlexDirection: TCSSFlexDirection;
    FlexGrow: TCSSNumber;       // default 0
    FlexShrink: TCSSNumber;     // default 1
    FlexWrap: TCSSFlexWrap;
    Border: array[TCSSSide] of TCSSBorder;
    Margin: array[TCSSSide] of TCSSLength;
    Padding: array[TCSSSide] of TCSSLength;
    JustifyContent: TCSSJustifyContent;
    Order: TCSSInteger; // default 0
    Overflow,                   // overflow-x
    OverflowY: TCSSOverflowType;
    ZIndex: Integer;            // paint order of siblings (positioned nodes), default 0
    Position: TCSSPosition;
    RadiusTopLeft,
    RadiusTopRight,
    RadiusBottomLeft,
    RadiusBottomRight: TCSSBorderRadius;
    RowGap,
    ColumnGap: TCSSLength;
    GridTemplateColumns,        // grid-template-columns: repeat(3, minmax(0, 1fr)), 200px 1fr, auto 1fr ...
    GridTemplateRows: String;
    GridColumnSpan,             // grid-column: span N (-1 = all columns, 0 = auto)
    GridRowSpan: Integer;       // grid-row: span N
    Specified: TCSSInheritedProps; // inherited properties set by this style
    TextAlign: TCSSTextAlign;
    WhiteSpace: TCSSWhiteSpace;
    Height,
    Width,
    MinHeight,
    MinWidth,
    MaxHeight,
    MaxWidth: TCSSLength;
    Top,
    Left,
    Right,
    Bottom: TCSSLength;
    Weight: Integer;        // "order" in CSS stylesheet
    Specificity: Integer;   // selector specificity (id * 10000 + class * 100 + element)
    SelectorText: String;   // selector of this rule (stylesheet items only)
    Selector: TCSSCompoundSelectors;  // parsed SelectorText (see CompileSelector)
    SelectorCompiled,
    SelectorValid: Boolean;
    CustomProps: TStringList;         // custom properties (--name: value)
    procedure CompileSelector;
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure Parse(const AValue: String);
    procedure ParseFromStyleSheet(AStyleSheet: TCSSStyleSheet; const APropertyName: String);
    procedure AddProperty(AName: String; AValue: String);
    procedure AddParsedProperty(AName: String; AValue: String);
    procedure Assign(Source: TPersistent); override;
    procedure Merge(AValue: TCSSItem);
    function LayoutKey: String;     // values which change layout (sizes, spacing, fonts, display ...)
    function PaintKey: String;      // values which change only painting (colors, borders, shadows, transforms ...)
  end;

  { TCSSStyleSheet }
  TCSSStyleSheet = class(TComponent)
  private
    FList: TStringList;
    FStyle: String;
    function GetSelectorByName(AName: String): TCSSItem;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TCSSItem;
    procedure SetStyle(AValue: String);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Selector[AName: String]: TCSSItem read GetSelectorByName;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TCSSItem read GetItem;
    function Append(const AValue: String): TCSSStyleSheet;
  published
    property Style: String read FStyle write SetStyle;
  end;

  { TCSSClassList }
  TCSSClassList = class                         // https://developer.mozilla.org/en-US/docs/Web/API/Element/classList
  private
    FList: TStringList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): String;
    function GetName: String;
    procedure SetName(AValue: String);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(AName: String): TCSSClassList;
    function Remove(AName: String): TCSSClassList;
    function Replace(AFrom, ATo: String): TCSSClassList;
    function Toggle(AName: String): TCSSClassList;
    function Contains(const AName: String): Boolean;
    property Count: Integer read GetCount;     // length
    property Name: String read GetName write SetName;
    property Item[AIndex: Integer]: String read GetItem;
  end;

  { THtmlSize }
  THtmlSize = class(TPersistent)
  public
    Position,
    ContentRect,        // MarginRect - Margin
    MarginRect: TRect;  // Margin rect (whole region)
    BaseLine: Integer;  // px from bottom of MarginRect
    Border,
    Padding,
    Margin: TRect;
    ContentWidth,                // content + border + padding
    ContentHeight: Integer;      // content + border + padding
    FontSize: Single;            // computed font size in px (0 = default font)
    function TopSpace: Integer; inline;
    function LeftSpace: Integer; inline;
    function RightSpace: Integer; inline;
    function BottomSpace: Integer; inline;
    function RealContentWidth: Integer; inline;
    function RealContentRect: TRect; inline; // ContentRect - Border - Padding
  end;

  THtmlNodeArray = array of THtmlNode;

  { THtmlNode }
  THtmlNode = class(TPersistent)
  private
    FOnClick: TNotifyEvent;
    FHovered: Boolean;
    FActive: Boolean;             // mouse is pressed on node (:active)
    FViewportWidth: Integer;      // root node only: width for responsive variants (sm:, md: ...)
    FParentControl: TControl;
    FChangedMark: Boolean;        // node was changed since last layout of shape (its area is painted again)
    FDirtyOld: TRect;             // root only: old area of changed and removed nodes
    FHasChanges, FChangedAll: Boolean;   // root only: some nodes were changed, whole tree is painted again
    FFreeMe: Boolean;
    FElementName,                 // div, span ...
    FId: String;                  // id for access
    FAlignControlWasHidden: Boolean; // store if AlignControl was hidden by display style
    FAlignControl: TControl;
    FTotalCount,
    FChildCount: Integer;
    FFirstNode,
    FLastNode,
    FFirstChild,
    FNextSibling,
    FPrevSibling: THtmlNode;
    FInlineStyle,
    FHoverStyle: String;
    FText: String;
    FCompStyle: TCSSItem;          // computed active to render style
    FCompSize: THtmlSize;          // computed size

    // cache section here
    FCachedFont: TCSSFont;
    FStyleSheet: TCSSStyleSheet;
    FClassList: TCSSClassList;
    FAttributes: TStringList;     // html attributes (src ...)
    FData: TObject;               // user data (object), freed with node when FOwnsData
    FOwnsData: Boolean;
    FScrollX, FScrollY: Integer;  // scroll position of content (overflow auto/scroll/hidden)
    FScrollMin, FScrollMax: TPoint;
    FVThumb, FHThumb: TRect;      // scrollbar thumbs (last paint)
    FFocused: Boolean;            // :focus (set by application or TCSSShape for aligned controls)
    FTransform: TCSSMatrix2D;     // transformation relative to border box (see ComputeTransform)
    FTransformKind: TCSSTransformKind;
    FTransformBmp: TBitmap;       // cached painted node for scale, rotate
    FTransformKey: String;
    FTransformTarget: TCSSMatrix2D;     // transformation from styles (FTransform is animated)
    FTransformSrc: array of LongWord;   // cached source of transformed node (premultiplied ARGB)
    FTransformSrcW, FTransformSrcH: Integer;
    FTransformSrcKey: String;
    FAnim: PCSSAnim;              // running transition or animation (nil = none)
    FColorAnimated: Boolean;      // inherited color is animated by transition of ancestor
    FStyled: Boolean;             // node was painted (transitions start only for painted nodes, as in browser)
    FTransformSig: String;        // resolved transform properties (change starts transition)
    FClampKey, FClampResult: String;   // line-clamp: text with ellipsis for width, lines, font and text (cache)
    FStickyDY: Integer;           // position: sticky - vertical offset of painted node (scroll of container)
    FBgCache: array[0..5] of record   // cached background bitmaps: 0..3 corners, 4 whole, 5 gradient strip
      Key: String;
      Bmp: TBitmap;
    end;
    FVisible: Boolean;
    FPixelRatio: Single;          // root node only: scale factor for high dpi
    FPaintScale: Single;          // root node only: device pixels per canvas pixel (2 on macOS Retina)
    FRenderScale: Single;         // root node only: scale of offscreen rendering of transformed node (default font is scaled)
    FLayoutRoot: Boolean;         // LayoutTo was called for this node
    // layout cache: nested flex containers lay out items several times with the same input
    FLayPass: Cardinal;           // layout pass of cache
    FLayResults: array[0..7] of TCSSLayoutResult;
    FLayCount: Integer;
    FLayState, FLayWanted: TCSSLayoutKey;   // input of current layout of children, input of last request
    FLayWantedPW, FLayWantedPH: Integer;    // parent size of last request
    FLayoutWidth,                 // size for root node set by LayoutTo (-1 = auto)
    FLayoutHeight: Integer;
    function GetStyleValue(AName: String): String;
    procedure LayoutCalcPosition(ANode: THtmlNode; TargetWidth,
      TargetHeight: Integer; out NewWidth, NewHeight: Integer);
    procedure LayoutDoFlexAlign(AParentNode: THtmlNode; AList: TList; AWidth,
      AHeight: Integer; out NewWidth, NewHeight: Integer);
    function IsWhiteSpaceText: Boolean;     // whitespace between elements in markup (no flex or grid item)
    function HasPrevElementSibling: Boolean;
    function StickyOffset: Integer;
    procedure UpdateStickyOffsets;
    function ClampLinesHeight(ALines: Integer): Integer;
    function ClampedText(AMaxWidth: Integer): String;
    function EllipsisText(AMaxWidth: Integer): String;
    procedure LayoutDoGrid(AParentNode: THtmlNode; AList: TList; AWidth, AHeight: Integer; out NewWidth, NewHeight: Integer);
    function LayoutDoVerticalAlign(AList: TList; ClearList: Boolean = True): Integer;
    procedure LayoutGetNodeSize(ANode: THtmlNode; ParentWidth,
      ParentHeight: Integer; InFlex: Boolean = False; AForceWidth: Integer = -1; AForceHeight: Integer = -1);
    procedure ResolveInheritedStyle;

    procedure IntSetAlignControl(AValue: TControl);
    procedure SetHovered(AValue: Boolean);
    procedure SetHoverStyle(AValue: String);
    procedure SetInlineStyle(AValue: String);
    procedure SetStyleValue(AName: String; AValue: String);
  public
    Tag: LongInt;                 // user data (number)
    TagStr: String;               // user data (text)
    RootNode,
    ParentNode: THtmlNode;
  protected
    procedure DrawNode(ACanvas: TCanvas; AClipRect: TRect); virtual;
    procedure CalculateSize(out AWidth, AHeight, ABaseLine: Integer);virtual;
    procedure MeasureText(AMaxWidth: Integer; out AWidth, AHeight, ABaseLine: Integer); virtual;
    procedure AssignFontTo(AFont: TFont);
    function BorderColor(ASide: TCSSSide): TColor;
    function FlexTextRect(const AContent: TRect): TRect;
    function MeasureLongestWord: Integer;
    function MinContentWidth(AAutoMinimum: Boolean = False): Integer;
    procedure CalcRadius(AWidth, AHeight: Integer; out ATopLeft, ATopRight, ABottomRight, ABottomLeft: TPoint);
    procedure PaintBackgroundAndBorder(ACanvas: TCanvas);
    procedure BackgroundImageRect(AImage: TCSSImageData; AWidth, AHeight: Integer; out ARect: TRectF);
    function BackgroundLayer(const S: TCSSPaintShape; AWidth, AHeight: Integer; const AImage: String;
      const ACornerW, ACornerH: array of Integer; AScale: Single; ASlot: Integer; const ARegion: TRect): TBitmap;
    function GradientStrip(const AGradient: TCSSGradient; AWidth, AHeight: Integer; const AKey: String): TBitmap;
    function ParseShadows(const AValue: String): TCSSShadowArray;
    procedure PaintBoxShadow(ACanvas: TCanvas);
    procedure PaintInsetShadow(ACanvas: TCanvas);
    procedure ComputeTransform;
    procedure UpdateTransformKind;
    procedure UpdateTransitions(const AOldColors: TCSSColorChannels; AOldOpacity: Single; const AOldMatrix: TCSSMatrix2D);
    procedure ApplyAnimation(ANow: QWord; out ADone: Boolean);
    procedure StopAnimation;
    function AnimMaxScale: Single;
    procedure OffsetSubtree(DX, DY: Integer);
    procedure PaintNodeTree(ACanvas: TCanvas; const AClipRect: TRect);
    procedure PaintTransformed(ACanvas: TCanvas; const AClipRect: TRect);
    procedure SaveLayout(var AStates: TCSSLayoutStates);
    procedure PlaceAbsolute(AWidth, AHeight: Integer);
    procedure UpdateScrollRange;
    procedure PaintScrollbars(ACanvas: TCanvas);
  public
    constructor Create(AInlineStyle: String = '');virtual;
    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;
    function ApplyStyle: THtmlNode;
    function ApplyStyles: THtmlNode;
    function RestyleState(ADeep: Boolean; var ADirty: TRect): Boolean;   // after hover/active/focus change, True = layout needed
    procedure ApplySubtree(ANode: THtmlNode);
    procedure ApplyStyleForNode(ANode: THtmlNode);
    procedure ApplyElementDefaults(ANode: THtmlNode);
    function MatchesCompound(const ACompound: TCSSCompoundSelector): Boolean;
    function Matches(const ASelector: TCSSCompoundSelectors): Boolean; overload;
    function Matches(const ASelector: String): Boolean; overload;
    function UtilityClass(const AClassName: String; out ADeclarations: String; out ASpecificity, AOrder: Integer): Boolean;
    function SiblingIndex: Integer;
    function HasHoveredAncestorWithClass(const AClass: String): Boolean;
    function AddNode(ANode: THtmlNode): THtmlNode;
    function AppendTo(AParentNode: THtmlNode): THtmlNode;
    function InsertBefore(ANode, ARefNode: THtmlNode): THtmlNode;   // like DOM, ARefNode = nil appends
    function GetNext(ANode: THtmlNode; GoAboveChildren: Boolean = False): THtmlNode;
    function GetElementsByClassName(AName: String): THtmlNodeArray;
    function GetElementById(const AId: String): THtmlNode;
    procedure LayoutTo(ALeft, ATop, AWidth, AHeight: Integer);
    procedure AlignControlsTo(ALeft, ATop: Integer);
    function NodeAtPosition(APos: TPoint; AClickable: Boolean = True): THtmlNode;   // top node (clickable: its nearest node with OnClick)
    function HitTest(const APos: TPoint): Boolean; virtual;
    function Animating: Boolean;                        // root: some nodes are animated (transition or animation)
    function AnimationTick(ANow: QWord): Boolean;      // root: next frame of animations, True = repaint
    function AnimationBounds: TRect;                    // root: painted area of animated nodes
    function AnimationRects: TCSSRectArray;             // root: painted areas of animated nodes (one per node)
    function AnimatingTransitions: Boolean;             // root: some transitions run (built-in animations need less fps)
    function TransformPoint(const P: TPointF): TPointF;
    function UntransformPoint(const P: TPointF): TPointF;
    function ScreenToLayout(const P: TPointF): TPointF;
    function LayoutToScreen(const P: TPointF): TPointF;
    function TransformedBounds(const ARect: TRect): TRect;
    property TransformKind: TCSSTransformKind read FTransformKind;
    property TransformMatrix: TCSSMatrix2D read FTransform;     // shown transformation (can be animated)
    function ClipsContent: Boolean;
    function PaddingBox: TRect;
    function CanScroll(DX, DY: Integer): Boolean;
    function ScrollBy(DX, DY: Integer): Boolean;
    function SetScroll(AX, AY: Integer): Boolean;
    function ThumbAt(const APos: TPoint): Integer;
    function ScrollByThumb(AAxis, AStartScroll, ADelta: Integer): Boolean;
    function PaintOrder: THtmlNodeArray;
    function HasFocusWithin: Boolean;
    function ScreenToLayoutClip(const P: TPointF; out AVisible: Boolean): TPointF;
    function ScreenClipRect: TRect;
    property ScrollX: Integer read FScrollX;
    property ScrollY: Integer read FScrollY;
    property ScrollMin: TPoint read FScrollMin;
    property ScrollMax: TPoint read FScrollMax;
    property Focused: Boolean read FFocused write FFocused;
    function GetAttribute(const AName: String): String;
    procedure SetAttribute(const AName, AValue: String);
    property Attributes[const AName: String]: String read GetAttribute write SetAttribute;   // also user texts (data-*)
    property Data: TObject read FData write FData;                   // user object
    property OwnsData: Boolean read FOwnsData write FOwnsData;       // Data is freed with node
    procedure PaintTo(ACanvas: TCanvas); overload;
    procedure PaintTo(ACanvas: TCanvas; const AClipRect: TRect); overload;
    function CalcLength(const AValue: TCSSLength; AParentLength: Integer): Integer;
    function ResolveVars(const AValue: String; ADepth: Integer = 0): String;
    function EffectiveColor(const AColor: TCSSColor): TColor;
    function BorderWidth(ASide: TCSSSide): Integer;
    function SetAlignControl(AValue: TControl): THtmlNode;
    function SetClass(AValues: String): THtmlNode;
    function SetInline(AValue: String): THtmlNode;
    function SetId(AValue: String): THtmlNode;
    function SetHover(AValue: String): THtmlNode;
    function SetOnClick(AValue: TNotifyEvent): THtmlNode;
    function SetTagStr(AValue: String): THtmlNode;
    function SetText(const AValue: String): THtmlNode;
    function Clear: THtmlNode;
    function Delete(ANode: THtmlNode): THtmlNode;
    procedure Detach;
    function CountNodes(ANode: THtmlNode): Integer;
    procedure Changed;
    procedure NoteChanged(ANode: THtmlNode);    // root: node (with subtree) is painted again, its old area is remembered
    function TakeDirtyRect(const AOldRects: TCSSRectArray): TRect;   // root: area to paint after layout (changes are cleared)
    function PaintedRect: TRect;                // area of node on screen (with shadow and transform), empty if not visible
    function SubtreePaintedRect: TRect;         // painted area of node and its descendants
    function PaintedRects: TCSSRectArray;       // painted areas of all nodes (preorder), compared after layout
    property HasChanges: Boolean read FHasChanges;
    property ChangedAll: Boolean read FChangedAll;

    property ClassList: TCSSClassList read FClassList;
    property CompStyle: TCSSItem read FCompStyle write FCompStyle;
    property CompSize: THtmlSize read FCompSize write FCompSize;
    property Element: String read FElementName write FElementName;
    property FirstChild: THtmlNode read FFirstChild;
    property Id: String read FId write FId;
    property ParentControl: TControl read FParentControl write FParentControl;
    property Style[AName: String]: String read GetStyleValue write SetStyleValue;
    property Text: String read FText write FText;
    property Hovered: Boolean read FHovered write SetHovered;
    property Active: Boolean read FActive write FActive;
    property ViewportWidth: Integer read FViewportWidth write FViewportWidth;  // used from RootNode only, -1 = unknown
    property ChildCount: Integer read FChildCount;
    property Visible: Boolean read FVisible;     // computed by layout (display:none node or parent)
    property PixelRatio: Single read FPixelRatio write FPixelRatio;  // used from RootNode only
    property PaintScale: Single read FPaintScale write FPaintScale;  // used from RootNode only, bitmaps are rendered in this resolution
  published
    property AlignControl: TControl read FAlignControl write IntSetAlignControl;
    property InlineStyle: String read FInlineStyle write SetInlineStyle;
    property HoverStyle: String read FHoverStyle write SetHoverStyle;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property StyleSheet: TCSSStyleSheet read FStyleSheet write FStyleSheet;
  end;

  THtmlNodeList = class
  end;

  { utility classes (Tailwind like) support, see csstailwind.pas }
  TCSSUtilityResolver = function(const AClassName: String; out ADeclarations: String; out AOrder: Integer): Boolean;

  ICSSControl = interface
    [HTMLInterface]
    function GetBodyNode: THtmlNode;
    procedure Changed;
  end;

  TColorObject = class
    Value: TColor;
  end;

var
  CSSRootFontSize: Single = CSS_DEFAULT_FONT_SIZE;   // px, base for "rem" units
  CSSDefaultBoxSizing: TCSSBoxSizing = cbxContentBox; // initial box-sizing value (Tailwind like styles use border-box)
  CSSAntialiasing: Boolean = True;                   // antialiasing of rounded corners and border joins
  CSSDarkMode: Boolean = False;                      // dark: variant of utility classes is active (apply styles after change)
  CSSAnimationsEnabled: Boolean = True;              // False: transitions and animations are off (form designer)

type
  TCSSStats = record             // counters of layout and painting for performance tuning (application reads and resets them)
    Layouts, Paints: Integer;
    LayoutMs, PaintMs, MaxPaintMs: Double;   // times are added by TCSSShape
    PaintPixels: Int64;          // area of painted rectangles (control pixels)
    Bitmaps, Texts: Integer;     // drawn bitmaps (corners, shadows, icons ...) and texts
    BitmapMs, TextMs: Double;    // time of drawing bitmaps and texts
    StretchPixels: Int64;        // area of bitmaps drawn resized (eg. semi-transparent backgrounds, sides of shadows)
    Clips: Integer;              // changes of clip rect of canvas
    ClipMs: Double;
  end;

var
  CSSStats: TCSSStats;
  CSSFastBlend: Boolean = True;  // Windows: cached bitmaps are drawn by AlphaBlend directly (LCL premultiplies them in every draw)

  CSSUtilityResolver: TCSSUtilityResolver = nil;  // resolve unknown classes to CSS declarations

  procedure ParseCSS(ACSS: String; ATarget: TStringList);
  function ParseSelector(const ASelector: String; out ASpecificity: Integer): TCSSCompoundSelectors;
  function CSSToColor(AValue: String): TCSSColor;
  function CSSToLength(AValue: String): TCSSLength;
  function CSSResolveUtility(const AClassName: String; out ADeclarations: String; out AOrder: Integer): Boolean;
  procedure CSSClearUtilityCache;
  procedure CSSClearPaintCache;
  procedure CSSBeginUpdate;     // many nodes are changed: shapes are not laid out after every change,
  procedure CSSEndUpdate;       // changed shapes are laid out once at the end (calls can be nested)
  procedure CSSUpdateForget(AControl: TControl);   // control is destroyed (removed from pending updates)
  function CSSUpdatePending(AControl: TControl): Boolean;   // in CSSBeginUpdate: control is laid out in CSSEndUpdate
  function CSSAlphaBitmap(R, G, B, A: Byte): TBitmap;
  procedure CSSRegisterImage(const AName: String; AGraphic: TGraphic);
  function StrBefore(const AValue: String; const ASubstr: String): String;
  function StrAfter(const AValue: String; const ASubstr: String): String;
  function StrBetween(const AValue: String; const AStart, AEnd: String): String;
  function HTMLDiv(AInlineStyle: String; AId: String = ''): THtmlNode;
  function HTMLSpan(AInlineStyle: String; AText: String = ''; AId: String = ''): THtmlNode;
  function HTMLNode(const AClass: String; const AText: String = ''; const AElement: String = 'div'): THtmlNode;
  function CSSTimeMs: Double;    // high resolution time in ms (for measuring)
  // PointF and RectF are not in unit Types of FPC 3.2.2 (only in newer versions), they can be used from here
  function PointF(AX, AY: Single): TPointF; inline;
  function RectF(ALeft, ATop, ARight, ABottom: Single): TRectF; inline;

implementation

{$ifdef unix}
uses
  Unix;
{$endif}

{$ifdef windows}
function QueryPerformanceCounter(var ACount: Int64): LongBool; stdcall; external 'kernel32' name 'QueryPerformanceCounter';
function QueryPerformanceFrequency(var AFreq: Int64): LongBool; stdcall; external 'kernel32' name 'QueryPerformanceFrequency';
{$endif}

function CSSTimeMs: Double;
{$ifdef windows}
var
  C, F: Int64;
begin
  C := 0;
  F := 0;
  QueryPerformanceCounter(C);
  QueryPerformanceFrequency(F);
  if F > 0 then Result := Double(C) * 1000 / Double(F) else Result := GetTickCount64;   // Double: Single loses ms
end;
{$else}{$ifdef unix}
var
  TV: TTimeVal;
begin
  fpgettimeofday(@TV, nil);
  Result := Double(TV.tv_sec) * 1000 + Double(TV.tv_usec) / 1000;   // Double: Single loses ms
end;
{$else}
begin
  Result := GetTickCount64;
end;
{$endif}{$endif}

{$ifdef windows}
type
  { TCSSWinBitmap - cached bitmap with premultiplied copy for AlphaBlend. LCL creates a premultiplied copy of a
    32 bit bitmap in every draw, which is slow when hundreds of corners, shadows and icons are painted. }
  TCSSWinBitmap = class(TBitmap)
  private
    FDC: HDC;
    FDib, FOldBmp: HBITMAP;
  public
    procedure Prepare(AImage: TLazIntfImage);
    destructor Destroy; override;
  end;

function WinAlphaBlend(ADest: HDC; X, Y, W, H: Integer; ASrc: HDC; SX, SY, SW, SH: Integer; ABlend: LongWord): LongBool;
  stdcall; external 'msimg32.dll' name 'AlphaBlend';
{$endif}

type
  { TCSSKeyList - sorted cache with exact keys, compared byte by byte (default comparison of TStringList uses
    locale, which is slow: caches are searched for every corner, shadow and utility class) }
  TCSSKeyList = class(TStringList)
  protected
    function DoCompareText(const S1, S2: String): PtrInt; override;
  end;

function TCSSKeyList.DoCompareText(const S1, S2: String): PtrInt;
begin
  Result := CompareStr(S1, S2);
end;

(*
  Draw cached bitmap (resized when it has higher resolution, eg. Retina), counted in CSSStats
*)
procedure DrawCachedBitmap(ACanvas: TCanvas; const ARect: TRect; ABitmap: TBitmap);
var
  T: Double;
begin
  Inc(CSSStats.Bitmaps);
  if (ABitmap.Width <> ARect.Width) or (ABitmap.Height <> ARect.Height) then
    Inc(CSSStats.StretchPixels, Int64(ARect.Width) * ARect.Height);
  T := CSSTimeMs;
  {$ifdef windows}
  if CSSFastBlend and (ABitmap is TCSSWinBitmap) and (TCSSWinBitmap(ABitmap).FDC <> 0) then begin
    if (ARect.Width > 0) and (ARect.Height > 0) then
      WinAlphaBlend(ACanvas.Handle, ARect.Left, ARect.Top, ARect.Width, ARect.Height, TCSSWinBitmap(ABitmap).FDC, 0, 0,
        ABitmap.Width, ABitmap.Height, $01FF0000);    // AC_SRC_OVER, constant alpha 255, AC_SRC_ALPHA (premultiplied)
  end else
  {$endif}
  if (ABitmap.Width = ARect.Width) and (ABitmap.Height = ARect.Height) then ACanvas.Draw(ARect.Left, ARect.Top, ABitmap)
    else ACanvas.StretchDraw(ARect, ABitmap);
  CSSStats.BitmapMs := CSSStats.BitmapMs + CSSTimeMs - T;
end;

(*
  Clip rect of canvas (counted in CSSStats). It is set always, also when it is the same: Cocoa can lose clip of bitmap
  canvas after drawing. AEnable: clipping is enabled too (getter of Clipping says clip of canvas, setter enables it).
*)
procedure SetCanvasClip(ACanvas: TCanvas; const ARect: TRect; AEnable: Boolean = False);
var
  T: Double;
begin
  T := CSSTimeMs;
  if AEnable then ACanvas.Clipping := True;
  ACanvas.ClipRect := ARect;
  Inc(CSSStats.Clips);
  CSSStats.ClipMs := CSSStats.ClipMs + CSSTimeMs - T;
end;

function PointF(AX, AY: Single): TPointF; inline;
begin
  Result.x := AX;
  Result.y := AY;
end;

function RectF(ALeft, ATop, ARight, ABottom: Single): TRectF; inline;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
end;

const
  CSS_COLOR_KEYWORDS : array[0..147] of record         // https://developer.mozilla.org/en-US/docs/Web/CSS/named-color
    k: String;                                        // key
    v: String;                                        // value stored in CSS format is slow but better for future
  end = (
    (k:'aliceblue'; v:'#f0f8ff'),
    (k:'antiquewhite'; v:'#faebd7'),
    (k:'aqua'; v:'#00ffff'),
    (k:'aquamarine'; v:'#7fffd4'),
    (k:'azure'; v:'#f0ffff'),
    (k:'beige'; v:'#f5f5dc'),
    (k:'bisque'; v:'#ffe4c4'),
    (k:'black'; v:'#000000'),
    (k:'blanchedalmond'; v:'#ffebcd'),
    (k:'blue'; v:'#0000ff'),
    (k:'blueviolet'; v:'#8a2be2'),
    (k:'brown'; v:'#a52a2a'),
    (k:'burlywood'; v:'#deb887'),
    (k:'cadetblue'; v:'#5f9ea0'),
    (k:'chartreuse'; v:'#7fff00'),
    (k:'chocolate'; v:'#d2691e'),
    (k:'coral'; v:'#ff7f50'),
    (k:'cornflowerblue'; v:'#6495ed'),
    (k:'cornsilk'; v:'#fff8dc'),
    (k:'crimson'; v:'#dc143c'),
    (k:'cyan'; v:'#00ffff'),
    (k:'darkblue'; v:'#00008b'),
    (k:'darkcyan'; v:'#008b8b'),
    (k:'darkgoldenrod'; v:'#b8860b'),
    (k:'darkgray'; v:'#a9a9a9'),
    (k:'darkgreen'; v:'#006400'),
    (k:'darkgrey'; v:'#a9a9a9'),
    (k:'darkkhaki'; v:'#bdb76b'),
    (k:'darkmagenta'; v:'#8b008b'),
    (k:'darkolivegreen'; v:'#556b2f'),
    (k:'darkorange'; v:'#ff8c00'),
    (k:'darkorchid'; v:'#9932cc'),
    (k:'darkred'; v:'#8b0000'),
    (k:'darksalmon'; v:'#e9967a'),
    (k:'darkseagreen'; v:'#8fbc8f'),
    (k:'darkslateblue'; v:'#483d8b'),
    (k:'darkslategray'; v:'#2f4f4f'),
    (k:'darkslategrey'; v:'#2f4f4f'),
    (k:'darkturquoise'; v:'#00ced1'),
    (k:'darkviolet'; v:'#9400d3'),
    (k:'deeppink'; v:'#ff1493'),
    (k:'deepskyblue'; v:'#00bfff'),
    (k:'dimgray'; v:'#696969'),
    (k:'dimgrey'; v:'#696969'),
    (k:'dodgerblue'; v:'#1e90ff'),
    (k:'firebrick'; v:'#b22222'),
    (k:'floralwhite'; v:'#fffaf0'),
    (k:'forestgreen'; v:'#228b22'),
    (k:'fuchsia'; v:'#ff00ff'),
    (k:'gainsboro'; v:'#dcdcdc'),
    (k:'ghostwhite'; v:'#f8f8ff'),
    (k:'gold'; v:'#ffd700'),
    (k:'goldenrod'; v:'#daa520'),
    (k:'gray'; v:'#808080'),
    (k:'green'; v:'#008000'),
    (k:'greenyellow'; v:'#adff2f'),
    (k:'grey'; v:'#808080'),
    (k:'honeydew'; v:'#f0fff0'),
    (k:'hotpink'; v:'#ff69b4'),
    (k:'indianred'; v:'#cd5c5c'),
    (k:'indigo'; v:'#4b0082'),
    (k:'ivory'; v:'#fffff0'),
    (k:'khaki'; v:'#f0e68c'),
    (k:'lavender'; v:'#e6e6fa'),
    (k:'lavenderblush'; v:'#fff0f5'),
    (k:'lawngreen'; v:'#7cfc00'),
    (k:'lemonchiffon'; v:'#fffacd'),
    (k:'lightblue'; v:'#add8e6'),
    (k:'lightcoral'; v:'#f08080'),
    (k:'lightcyan'; v:'#e0ffff'),
    (k:'lightgoldenrodyellow'; v:'#fafad2'),
    (k:'lightgray'; v:'#d3d3d3'),
    (k:'lightgreen'; v:'#90ee90'),
    (k:'lightgrey'; v:'#d3d3d3'),
    (k:'lightpink'; v:'#ffb6c1'),
    (k:'lightsalmon'; v:'#ffa07a'),
    (k:'lightseagreen'; v:'#20b2aa'),
    (k:'lightskyblue'; v:'#87cefa'),
    (k:'lightslategray'; v:'#778899'),
    (k:'lightslategrey'; v:'#778899'),
    (k:'lightsteelblue'; v:'#b0c4de'),
    (k:'lightyellow'; v:'#ffffe0'),
    (k:'lime'; v:'#00ff00'),
    (k:'limegreen'; v:'#32cd32'),
    (k:'linen'; v:'#faf0e6'),
    (k:'magenta'; v:'#ff00ff'),
    (k:'maroon'; v:'#800000'),
    (k:'mediumaquamarine'; v:'#66cdaa'),
    (k:'mediumblue'; v:'#0000cd'),
    (k:'mediumorchid'; v:'#ba55d3'),
    (k:'mediumpurple'; v:'#9370db'),
    (k:'mediumseagreen'; v:'#3cb371'),
    (k:'mediumslateblue'; v:'#7b68ee'),
    (k:'mediumspringgreen'; v:'#00fa9a'),
    (k:'mediumturquoise'; v:'#48d1cc'),
    (k:'mediumvioletred'; v:'#c71585'),
    (k:'midnightblue'; v:'#191970'),
    (k:'mintcream'; v:'#f5fffa'),
    (k:'mistyrose'; v:'#ffe4e1'),
    (k:'moccasin'; v:'#ffe4b5'),
    (k:'navajowhite'; v:'#ffdead'),
    (k:'navy'; v:'#000080'),
    (k:'oldlace'; v:'#fdf5e6'),
    (k:'olive'; v:'#808000'),
    (k:'olivedrab'; v:'#6b8e23'),
    (k:'orange'; v:'#ffa500'),
    (k:'orangered'; v:'#ff4500'),
    (k:'orchid'; v:'#da70d6'),
    (k:'palegoldenrod'; v:'#eee8aa'),
    (k:'palegreen'; v:'#98fb98'),
    (k:'paleturquoise'; v:'#afeeee'),
    (k:'palevioletred'; v:'#db7093'),
    (k:'papayawhip'; v:'#ffefd5'),
    (k:'peachpuff'; v:'#ffdab9'),
    (k:'peru'; v:'#cd853f'),
    (k:'pink'; v:'#ffc0cb'),
    (k:'plum'; v:'#dda0dd'),
    (k:'powderblue'; v:'#b0e0e6'),
    (k:'purple'; v:'#800080'),
    (k:'rebeccapurple'; v:'#663399'),
    (k:'red'; v:'#ff0000'),
    (k:'rosybrown'; v:'#bc8f8f'),
    (k:'royalblue'; v:'#4169e1'),
    (k:'saddlebrown'; v:'#8b4513'),
    (k:'salmon'; v:'#fa8072'),
    (k:'sandybrown'; v:'#f4a460'),
    (k:'seagreen'; v:'#2e8b57'),
    (k:'seashell'; v:'#fff5ee'),
    (k:'sienna'; v:'#a0522d'),
    (k:'silver'; v:'#c0c0c0'),
    (k:'skyblue'; v:'#87ceeb'),
    (k:'slateblue'; v:'#6a5acd'),
    (k:'slategray'; v:'#708090'),
    (k:'slategrey'; v:'#708090'),
    (k:'snow'; v:'#fffafa'),
    (k:'springgreen'; v:'#00ff7f'),
    (k:'steelblue'; v:'#4682b4'),
    (k:'tan'; v:'#d2b48c'),
    (k:'teal'; v:'#008080'),
    (k:'thistle'; v:'#d8bfd8'),
    (k:'tomato'; v:'#ff6347'),
    (k:'turquoise'; v:'#40e0d0'),
    (k:'violet'; v:'#ee82ee'),
    (k:'wheat'; v:'#f5deb3'),
    (k:'white'; v:'#ffffff'),
    (k:'whitesmoke'; v:'#f5f5f5'),
    (k:'yellow'; v:'#ffff00'),
    (k:'yellowgreen'; v:'#9acd32')
  );
var
  CSSColorList: TStringList;
  CSSFontFamilyCache: TStringList;   // resolved font-family values
  CSSDefaultFontPx: Integer = 0;     // see CSSDefaultFontHeight
  {$ifndef fmx}
  CSSMeasureBitmap: TBitmap;         // canvas for text measurement
  {$endif}
  CSSRuleCounter: Integer = 0;   // order of parsed rules (cascade order)
  
{$ifdef delphi}
function CompareRect(R1, R2: PRect): Boolean; // lcl source code
begin
  Result := (R1^.Left=R2^.Left) and (R1^.Top=R2^.Top) and
          (R1^.Bottom=R2^.Bottom) and (R1^.Right=R2^.Right);  
end;
{$endif}
  
function FPoint(x,y: Single): TFloatPoint; inline;
begin
  Result.x := x;
  Result.y := y;
end;

function StrBefore(const AValue: String; const ASubstr: String): String;
var
  I: Integer;
begin
  I := Pos(ASubstr, AValue);
  if I > 0 then  Result := Copy(AValue, 1, I -1)
    else Result := '';
end;

function StrAfter(const AValue: String; const ASubstr: String): String;
var
  I: Integer;
begin
  I := Pos(ASubstr, AValue);
  if I > 0 then  Result := Copy(AValue, I + Length(ASubstr), Length(AValue))
    else Result := '';
end;

(*
  Locale independent number parsing ("1.5" works also with "," decimal separator in system locale)
*)
function CSSStrToFloat(const AValue: String; out AResult: Single): Boolean;
var
  fs: TFormatSettings;
  D: Double;
begin
  fs := {$ifdef fpc}DefaultFormatSettings{$else}TFormatSettings.Invariant{$endif};
  fs.DecimalSeparator := '.';
  fs.ThousandSeparator := #0;
  Result := TryStrToFloat(Trim(AValue), D, fs);
  if Result then AResult := D else AResult := 0;
end;

function CSSStrToFloatDef(const AValue: String; ADefault: Single): Single;
begin
  if not CSSStrToFloat(AValue, Result) then Result := ADefault;
end;

function StrBetween(const AValue: String; const AStart, AEnd: String): String;
begin
  Result := StrBefore(StrAfter(AValue, AStart), AEnd);
end;

function StrPart(var AValue: String; const APipe: String='|'): String;
var
	i: Integer;
begin
	i := Pos(APipe, AValue);
	if i <> 0 then begin
		Result := Copy(AValue, 1, i - 1);
		AValue := Copy(AValue, i + Length(APipe), Length(AValue));
	end
	else begin
		Result := AValue;
		AValue := '';
	end;
end;

function HTMLDiv(AInlineStyle: String; AId: String): THtmlNode;
begin
  Result := THtmlNode.Create;
  Result.InlineStyle := AInlineStyle;
  Result.Id := AId;
end;

(*
  Create node with classes (utility classes), eg.: HTMLNode('px-4 py-2 rounded bg-blue-500 text-white', 'Save', 'span')
*)
function HTMLNode(const AClass: String; const AText: String; const AElement: String): THtmlNode;
begin
  Result := THtmlNode.Create;
  Result.FElementName := LowerCase(AElement);
  Result.Text := AText;
  Result.SetClass(AClass);
end;

function HTMLSpan(AInlineStyle: String; AText: String = ''; AId: String = ''): THtmlNode;
begin
  Result := THtmlNode.Create;
  Result.FElementName := 'span';
  Result.InlineStyle := AInlineStyle;
  Result.Id := AId;
  Result.Text := AText;
end;

(*
  Remove all comments and empty(double..) spaces and line breaks
*)
procedure CleanCSS(var AValue: String);
var
  S: String;
  I, T: Integer;
  CurCh, PrevCh: Char;
  InQuotes,
  InComment: Boolean;
begin
  if Length(AValue) = 0 then Exit;
  S := AValue;
  T := 1;
  PrevCh := #0;
  InComment := False;
  InQuotes := False;
  for I := 1 to Length(S) do begin
    CurCh  := S[I];
    if (not InComment) and not(CurCh in [#9, #10, #11, #13])  then begin
      S[T] := S[I];
      Inc(T);
    end;
    if CurCh in ['"', ''''] then InQuotes := not InQuotes;
    if CurCh in [#10, #11, #13] then InQuotes := False;
    if not InQuotes then begin
      if (CurCh = ' ') and (PrevCh = ' ') then Dec(T); // skip empty spaces
      if (CurCh ='*') and (PrevCh ='/') then begin
        InComment := True;
        Dec(T);
      end;
      if (CurCh ='/') and (PrevCh ='*') then begin
        InComment := False;
        Dec(T,1);
      end;
    end;
    PrevCh := CurCh;
  end;
  AValue := Copy(S, 1, T-1);
end;

function DivideToStringList(const AValue:String; Delimiter: Char; Sort: Boolean = False): TStringList;
var
  Len,
  I, J: Integer;
begin
  Result := TStringList.Create;
  Result.Sorted := Sort;
  if AValue = '' then exit;
  I := 1;
  J := 1;
  Len := Length(AValue);
  while I <= Len do begin
    if (AValue[I] = Delimiter) or (I = Len) then  begin
      if (I = Len) and (AValue[I] <> Delimiter) then Inc(I);
      if (I - J) > 0 then Result.Add(Copy(AValue, J, I - J));
      J := I + 1;
    end;
    Inc(I);
  end;
end;

function SplitParameters(const AValue: String; Delimiter: Char=' '): TStringArray;
const
  ExpandSize = 6;
var
  Count,
  Len,
  I, J: Integer;
  InRound: Integer;
begin
  Result := nil;
  if AValue = '' then exit;
  SetLength(Result, 10);
  Count :=0;
  I := 1;
  J := 1;
  InRound := 0;
  Len := Length(AValue);
  while I <= Len do begin
    if AValue[I] = '(' then
      Inc(InRound) else
    if AValue[I] = ')' then
      Dec(InRound);
    if ((AValue[I] = Delimiter) and (InRound<1)) or (I = Len) then begin
      if I = Len then Inc(I);
      if (I - J) > 0 then begin
        if Length(Result) <= Count then
          SetLength(Result, Length(Result) + ExpandSize);
        Result[Count] := Copy(AValue, J, I - J);
        Inc(Count);
        if (I > Len) and (Result[Count-1] = Delimiter) then Dec(Count);
      end;
      J := I + 1;
    end;
    Inc(I);
  end;
  SetLength(Result, Count);
end;

{$ifdef delphi}
function RGBToColor(R, G, B: Byte): TColor;
begin
  Result := (B shl 16) or (G shl 8) or R;
end;
{$endif}

function CSSToFontWeight(AValue: String): TCSSFontWeight;
var
  N: Integer;
begin
  Result.FontType := cfwUndefined;
  Result.Value := [];
  AValue := LowerCase(Trim(AValue));
  if (AValue = 'bold') or (AValue = 'bolder') then begin
    Result.FontType := cfwBold;
    Result.Value := [{$ifdef delphi}TFontStyle.{$endif}fsBold];
  end else
  if (AValue = 'normal') or (AValue = 'lighter') then
    Result.FontType := cfwNormal
  else
  if TryStrToInt(AValue, N) then begin     // 100..900, 600 and more is bold
    if N >= 600 then begin
      Result.FontType := cfwBold;
      Result.Value := [{$ifdef delphi}TFontStyle.{$endif}fsBold];
    end else
      Result.FontType := cfwNormal;
  end;
end;

function CSSToTextAlign(AValue: String): TCSSTextAlign;
begin
  if (AValue = 'left') or (AValue = 'start') then Result := ctaLeft else
  if (AValue = 'right') or (AValue = 'end') then Result := ctaRight else
  if AValue = 'center' then Result := ctaCenter else
  if AValue = 'justify' then Result := ctaJustify else
    Result := ctaUndefined;
end;

function CSSToAlignItems(AValue: String; ADefault: TCSSAlignItems = caiStretch): TCSSAlignItems;
begin
  if (AValue = 'flex-start') or (AValue = 'start') or (AValue = 'self-start') then Result := caiFlexStart else
  if (AValue = 'flex-end') or (AValue = 'end') or (AValue = 'self-end') then Result := caiFlexEnd else
  if AValue = 'center' then Result := caiCenter else
  if AValue = 'stretch' then Result := caiStretch else
  if AValue = 'baseline' then Result := caiBaseline else
  if AValue = 'auto' then Result := caiAuto else
    Result := ADefault;
end;

function CSSToJustifyContent(AValue: String): TCSSJustifyContent;
begin
  if (AValue = 'flex-end') or (AValue = 'end') or (AValue = 'right') then Result := cjcFlexEnd else
  if AValue = 'center' then Result := cjcCenter else
  if AValue = 'space-between' then Result := cjcSpaceBetween else
  if AValue = 'space-around' then Result := cjcSpaceAround else
  if AValue = 'space-evenly' then Result := cjcSpaceEvenly else
    Result := cjcFlexStart;
end;

function CSSToFlexDirection(AValue: String): TCSSFlexDirection;
begin
  if AValue = 'row-reverse' then Result := cfdRowReverse else
  if AValue = 'column' then Result := cfdColumn else
  if AValue = 'column-reverse' then Result := cfdColumnReverse else
    Result := cfdRow;
end;

function CSSToFlexWrap(AValue: String): TCSSFlexWrap;
begin
  if AValue = 'wrap' then Result := cfwWrap else
  if AValue = 'wrap-reverse' then Result := cfwWrapReverse else
    Result := cfwNoWrap;
end;

function CSSToOverflowType(AValue: String): TCSSOverflowType;
begin
  if AValue = 'hidden' then Result := cotHidden else
  if AValue = 'auto' then Result := cotAuto else
  if AValue = 'scroll' then Result := cotScroll else
    Result := cotVisible;
end;

function CSSToBorderStyle(AValue: String; out AStyle: TCSSBorderStyle): Boolean;
const
  Names: array[TCSSBorderStyle] of String = ('', 'none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset');
var
  S: TCSSBorderStyle;
begin
  Result := False;
  AStyle := cbsUndefined;
  if AValue = '' then Exit;
  for S := Succ(Low(TCSSBorderStyle)) to High(TCSSBorderStyle) do
    if Names[S] = AValue then begin
      AStyle := S;
      Exit(True);
    end;
end;

function CSSFontStyleFromName(S: String): TCSSFontStyle;
begin
  if S = 'italic' then Result := cfsItalic else
  if S.StartsWith('oblique') then Result := cfsOblique else
  if S = 'normal' then Result := cfsNormal else
    Result := cfsUndefined;
end;

(*
  Convert CSS length value. Returns False if AValue is not valid length.
  Supported: 0, auto, px, pt, em, rem, %, unitless number (as px)
*)
function TryCSSToLengthValue(AValue: String; out ALength: TCSSLength): Boolean;
  function NumberWithUnit(const AUnit: String; AType: TCSSLengthType): Boolean;
  begin
    Result := AValue.EndsWith(AUnit) and CSSStrToFloat(Copy(AValue, 1, Length(AValue) - Length(AUnit)), ALength.Value);
    if Result then ALength.LengthType := AType;
  end;
begin
  ALength.Value := 0;
  ALength.LengthType := cltUndefined;
  AValue := LowerCase(Trim(AValue));
  Result := True;
  if AValue = 'auto' then
    ALength.LengthType := cltAuto
  else
  if not (NumberWithUnit('px', cltPx) or NumberWithUnit('pt', cltPt) or NumberWithUnit('rem', cltRem) or
     NumberWithUnit('em', cltEm) or NumberWithUnit('%', cltPercentage) or NumberWithUnit('', cltPx)) then
    Result := False;
end;

function CSSToLength(AValue: String): TCSSLength;
begin
  TryCSSToLengthValue(AValue, Result);
end;

function CSSToPosition(AValue: String): TCSSPosition;
begin
  if AValue = 'relative' then Result := cpRelative else
  if AValue = 'absolute' then Result := cpAbsolute else
  if AValue = 'fixed' then Result := cpFixed else
  if AValue = 'sticky' then Result := cpSticky else
    Result := cpStatic;
end;

function CSSToDisplay(AValue: String): TCSSDisplayType;
begin
  if AValue = 'flex' then Result := cdtFlex else
  if (AValue = 'inline') or (AValue = 'inline-block') then Result := cdtInline else
  if AValue = 'inline-flex' then Result := cdtInlineFlex else
  if AValue = 'none' then Result := cdtNone else
  if (AValue = 'grid') or (AValue = 'inline-grid') then Result := cdtGrid else
    Result := cdtBlock;
end;

(*
  Time in ms: 150ms, 0.3s
*)
function CSSToTime(AValue: String): Integer;
begin
  AValue := LowerCase(Trim(AValue));
  if Copy(AValue, Length(AValue) - 1, 2) = 'ms' then
    Result := Round(CSSStrToFloatDef(Copy(AValue, 1, Length(AValue) - 2), 0))
  else if Copy(AValue, Length(AValue), 1) = 's' then
    Result := Round(CSSStrToFloatDef(Copy(AValue, 1, Length(AValue) - 1), 0) * 1000)
  else
    Result := 0;
  Result := Max(0, Result);
end;

function IsCSSTime(const AValue: String): Boolean;
begin
  Result := (AValue <> '') and (AValue[1] in ['0'..'9', '.']) and (AValue[Length(AValue)] = 's');
end;

function CSSToOpacity(AValue: String): Single;
begin
  AValue := Trim(AValue);
  if Copy(AValue, Length(AValue), 1) = '%' then
    Result := CSSStrToFloatDef(Copy(AValue, 1, Length(AValue) - 1), 100) / 100
  else
    Result := CSSStrToFloatDef(AValue, 1);
  Result := EnsureRange(Result, 0, 1);
end;

(*
  aspect-ratio: 16 / 9, 1.5, auto (0)
*)
function CSSToAspectRatio(AValue: String): Single;
var
  A, B: Single;
begin
  AValue := Trim(AValue);
  Result := 0;
  if (AValue = '') or SameText(AValue, 'auto') then Exit;
  if Pos('/', AValue) > 0 then begin
    A := CSSStrToFloatDef(Trim(StrBefore(AValue, '/')), 0);
    B := CSSStrToFloatDef(Trim(StrAfter(AValue, '/')), 0);
    if (A > 0) and (B > 0) then Result := A / B;
  end else
    Result := Max(0, CSSStrToFloatDef(AValue, 0));
end;

(*
  transition: <property> <duration> <timing-function> <delay>, ... (one duration and timing for all properties)
*)
procedure ParseTransition(AItem: TCSSItem; const AValue: String);
var
  Items, Parts: TStringArray;
  I, J: Integer;
  S, Props: String;
  TimeCount: Integer;
begin
  Props := '';
  TimeCount := 0;
  Items := SplitParameters(LowerCase(Trim(AValue)), ',');
  for I := 0 to High(Items) do begin
    Parts := SplitParameters(Trim(Items[I]), ' ');
    TimeCount := 0;
    for J := 0 to High(Parts) do begin
      S := Trim(Parts[J]);
      if S = '' then Continue;
      if IsCSSTime(S) then begin          // times and timing of first item are used
        if I = 0 then
          if TimeCount = 0 then AItem.TransitionDuration := CSSToTime(S) else AItem.TransitionDelay := CSSToTime(S);
        Inc(TimeCount);
      end else
      if (S = 'linear') or (Copy(S, 1, 4) = 'ease') or (Copy(S, 1, 12) = 'cubic-bezier') then begin
        if I = 0 then AItem.TransitionTiming := S;
      end
      else begin
        if Props <> '' then Props := Props + ',';
        Props := Props + S;
      end;
    end;
  end;
  if Props = '' then Props := 'all';
  AItem.TransitionProperty := Props;
end;

(*
  grid-column, grid-row: number of spanned tracks (span 2, span 2 / span 2), -1 = all columns (1 / -1), 0 = auto
*)
function CSSToGridSpan(AValue: String): Integer;
var
  P: Integer;
begin
  AValue := LowerCase(Trim(AValue));
  Result := 0;
  P := Pos('span', AValue);
  if P > 0 then
    Result := Max(0, StrToIntDef(Trim(StrBefore(Copy(AValue, P + 4, MaxInt) + '/', '/')), 0))
  else
  if (Pos('-1', AValue) > 0) and (Pos('/', AValue) > 0) then
    Result := -1;
end;

function CSSToFloat(AValue: String): TCSSFloatType;
begin
  if AValue.Equals('left') then Result := cftLeft else
  if AValue.Equals('right') then Result := cftRight else
    Result := cftNone;
end;

function CSSToCursor(AValue: String): TCursor;
begin
  if (AValue = 'pointer') or (AValue = 'grab') or (AValue = 'grabbing') then Result := crHandPoint else
  if AValue = 'wait' then Result := crHourGlass else
  if AValue = 'progress' then Result := crAppStart else
  if AValue = 'text' then Result := crIBeam else
  if AValue = 'move' then Result := crSizeAll else
  if AValue = 'crosshair' then Result := crCross else
  if AValue = 'help' then Result := crHelp else
  if AValue = 'not-allowed' then Result := crNo else
  if (AValue = 'ns-resize') or (AValue = 'row-resize') then Result := crSizeNS else
  if (AValue = 'ew-resize') or (AValue = 'col-resize') then Result := crSizeWE else
  if AValue = 'nesw-resize' then Result := crSizeNESW else
  if AValue = 'nwse-resize' then Result := crSizeNWSE else
  if AValue = 'none' then Result := crNone else
  Result := crDefault;
end;

(*
    Convert HTML colors to LCL colors
    Supported: #rgb, #rgba, #rrggbb, #rrggbbaa, rgb(), rgba(), named colors, transparent, currentcolor
    Note: alpha channel is not supported yet; fully transparent colors are converted to "transparent"
*)
function CSSToColor(AValue: String): TCSSColor;
  function HexByte(const S: String; out B: Byte): Boolean;
  var
    V: Integer;
  begin
    Result := TryStrToInt('$' + S, V) and (V >= 0) and (V <= 255);
    if Result then B := V else B := 0;
  end;
  function ColorPart(S: String; out B: Byte): Boolean;
  var
    F: Single;
  begin
    S := Trim(S);
    if S.EndsWith('%') then begin
      Result := CSSStrToFloat(Copy(S, 1, Length(S)-1), F);
      F := F * 2.55;
    end else
      Result := CSSStrToFloat(S, F);
    B := EnsureRange(Round(F), 0, 255);
  end;
var
  R, G, B, A: Byte;
  X: Integer;
  s: String;
  Parts: TStringArray;
  Alpha: Single;
  Ok: Boolean;
begin
  Result.ColorType := cctUndefined;
  Result.Value := 0;
  Result.Alpha := 255;
  AValue := LowerCase(Trim(AValue));
  if AValue = '' then
    Exit;
  A := 255;
  Ok := False;
  if AValue[1] = '#' then begin
    case Length(AValue) of
      4, 5: Ok := HexByte(AValue[2] + AValue[2], R) and HexByte(AValue[3] + AValue[3], G) and HexByte(AValue[4] + AValue[4], B) and
            ((Length(AValue) = 4) or HexByte(AValue[5] + AValue[5], A));
      7, 9: Ok := HexByte(Copy(AValue, 2, 2), R) and HexByte(Copy(AValue, 4, 2), G) and HexByte(Copy(AValue, 6, 2), B) and
            ((Length(AValue) = 7) or HexByte(Copy(AValue, 8, 2), A));
    end;
  end else
  if AValue.StartsWith('rgb') then begin
    s := StringReplace(StrBetween(AValue, '(', ')'), '/', ' ', [rfReplaceAll]);
    s := StringReplace(s, ',', ' ', [rfReplaceAll]);
    Parts := SplitParameters(Trim(s));
    if Length(Parts) >= 3 then begin
      Ok := ColorPart(Parts[0], R) and ColorPart(Parts[1], G) and ColorPart(Parts[2], B);
      if Ok and (Length(Parts) >= 4) then begin
        if Parts[3].EndsWith('%') then Alpha := CSSStrToFloatDef(Copy(Parts[3], 1, Length(Parts[3])-1), 100) / 100
          else Alpha := CSSStrToFloatDef(Parts[3], 1);
        A := EnsureRange(Round(Alpha * 255), 0, 255);
      end;
    end;
  end else
  if AValue = 'transparent' then begin
    Result.ColorType := cctTransparent;
    Exit;
  end else
  if AValue = 'currentcolor' then begin
    Result.ColorType := cctCurrentColor;
    Exit;
  end else
  if Assigned(CSSColorList) and CSSColorList.Find(AValue, X) then begin
    Result.Value := TColorObject(CSSColorList.Objects[X]).Value;
    Result.ColorType := cctNormal;
    Exit;
  end;
  if Ok then begin
    Result.Value := RGBToColor(R, G, B);
    Result.Alpha := A;
    if A = 0 then
      Result.ColorType := cctTransparent
    else
      Result.ColorType := cctNormal;
  end;
end;

(*
  generate css color table based on CSS_COLOR_KEYWORDS
*)

procedure InitCSSColors;
var
  I: Integer;
  Item: TColorObject;
begin
  CSSColorList := TStringList.Create;
  CSSColorList.Sorted := True;
  CSSColorList.OwnsObjects := True;
  for I := 0 to High(CSS_COLOR_KEYWORDS) do begin
    Item := TColorObject.Create;
    Item.Value := CSSToColor( CSS_COLOR_KEYWORDS[I].V).Value;
    CSSColorList.AddObject(CSS_COLOR_KEYWORDS[I].K, Item);
  end;
end;

(*
  Resolve CSS font-family list (eg. "Inter, ui-sans-serif, system-ui, sans-serif") to first installed font.
  Generic families are mapped to platform fonts, "default" is LCL default font.
*)
function CSSResolveFontFamily(const AFamily: String): String;
const
  {$if defined(darwin)}
  SERIF_FONT = 'Times'; MONO_FONT = 'Menlo';
  {$elseif defined(windows) or defined(mswindows)}
  SERIF_FONT = 'Times New Roman'; MONO_FONT = 'Consolas';
  {$else}
  SERIF_FONT = 'Serif'; MONO_FONT = 'Monospace';
  {$endif}
var
  Parts: TStringArray;
  I, X: Integer;
  Name, LName: String;
begin
  Result := 'default';
  if Trim(AFamily) = '' then Exit;
  if CSSFontFamilyCache = nil then begin
    CSSFontFamilyCache := TCSSKeyList.Create;
    CSSFontFamilyCache.Sorted := True;
    CSSFontFamilyCache.CaseSensitive := True;
  end;
  if CSSFontFamilyCache.Find(AFamily, X) then
    Exit(CSSFontFamilyCache.ValueFromIndex[X]);
  Parts := SplitParameters(AFamily, ',');
  for I := 0 to High(Parts) do begin
    Name := Trim(StringReplace(StringReplace(Parts[I], '"', '', [rfReplaceAll]), '''', '', [rfReplaceAll]));
    LName := LowerCase(Name);
    if (LName = 'sans-serif') or (LName = 'system-ui') or (LName = 'ui-sans-serif') or (LName = '-apple-system') or
      (LName = 'blinkmacsystemfont') or (LName = 'default') then Break;    // 'default'
    if (LName = 'serif') or (LName = 'ui-serif') then begin
      Result := SERIF_FONT;
      Break;
    end;
    if (LName = 'monospace') or (LName = 'ui-monospace') then begin
      Result := MONO_FONT;
      Break;
    end;
    {$ifdef fpc}
    try
      if Screen.Fonts.IndexOf(Name) >= 0 then begin
        Result := Name;
        Break;
      end;
    except
      Result := Name;     // font list is not available (eg. widgetset is not initialized)
      Break;
    end;
    {$endif}
  end;
  CSSFontFamilyCache.Add(AFamily + CSSFontFamilyCache.NameValueSeparator + Result);
end;

function TryCSSToLength(const AParts: TStringArray; var ATarget: TCSSLength): Boolean;
var
  I: Integer;
  L: TCSSLength;
begin
  Result := False;
  for I := 0 to High(AParts) do begin
    if AParts[I].IsEmpty then Continue;
    if TryCSSToLengthValue(AParts[I], L) and (L.LengthType <> cltAuto) then begin
      ATarget := L;
      AParts[I] := '';
      Exit(True);
    end;
  end;
end;

function CSSToBorderWidth(const AValue: String): TCSSLength;  // https://developer.mozilla.org/en-US/docs/Web/CSS/border-width
begin
  Result.LengthType := cltPx;
  if AValue = 'thin' then Result.Value := 1 else
  if AValue = 'medium' then Result.Value := 3 else
  if AValue = 'thick' then Result.Value := 5 else
    Result := CSSToLength(AValue);
end;

procedure TryCSSToBorderWidth(const AParts: TStringArray; var ATarget: TCSSLength);
var
  I: Integer;
begin
  for I := 0 to High(AParts) do
    if (AParts[I] = 'thin') or (AParts[I] = 'medium') or (AParts[I] = 'thick') then begin
      ATarget := CSSToBorderWidth(AParts[I]);
      AParts[I] := '';
      Exit;
    end;
  TryCSSToLength(AParts, ATarget);
end;

procedure TryCSSToBorderStyle(const AParts: TStringArray; var ATarget: TCSSBorderStyle);
var
  I: Integer;
begin
  for I := 0 to High(AParts) do
    if CSSToBorderStyle(AParts[I], ATarget) then begin
      AParts[I] := '';
      Exit;
    end;
end;

procedure TryCSSToColor(const AParts: TStringArray; var ATarget: TCSSColor);
var
  I: Integer;
  C: TCSSColor;
begin
  for I := 0 to High(AParts) do begin
    if AParts[I].IsEmpty then Continue;
    C := CSSToColor(AParts[I]);
    if C.ColorType <> cctUndefined then begin
      ATarget := C;
      AParts[I] := '';
      Exit;
    end;
  end;
end;

(*
  border shorthand: [width] [style] [color] in any order, missing values are set to initial values
  (width: medium, style: none, color: currentcolor)
*)
function CSSToBorder(AValue: String): TCSSBorder;
var
  Parts: TStringArray;
begin
  Result.Width.LengthType := cltPx;
  Result.Width.Value := 3;
  Result.Style := cbsNone;
  Result.Color.ColorType := cctCurrentColor;
  Result.Color.Value := 0;
  Result.Color.Alpha := 255;
  Parts := SplitParameters(LowerCase(AValue));
  TryCSSToBorderStyle(Parts, Result.Style);
  TryCSSToBorderWidth(Parts, Result.Width);
  TryCSSToColor(Parts, Result.Color);
end;

(*
    AValue can be:
      - one value
      - two values with space
*)
function CSSToBorderRadius(AValue: String): TCSSBorderRadius;
var
  Parts: TStringArray;
begin
  Parts := SplitParameters(Trim(AValue));
  if Length(Parts) = 0 then begin
    Result.Width.LengthType := cltUndefined;
    Result.Width.Value := 0;
  end else
    Result.Width := CSSToLength(Parts[0]);
  if Length(Parts) > 1 then
    Result.Height := CSSToLength(Parts[1])
  else
    Result.Height := Result.Width;
end;

(*
  font shorthand: [style] [weight] size[/line-height] family
*)
function CSSToFont(AValue: String; out ASpecified: TCSSInheritedProps): TCSSFont;
var
  Parts: TStringArray;
  I: Integer;
  S: String;
  W: TCSSFontWeight;
  FS: TCSSFontStyle;
  L: TCSSLength;
begin
  ASpecified := [];
  Result.Family := '';
  Result.Style := cfsUndefined;
  Result.TextDecoration := ctdUndefined;
  Result.Weight.FontType := cfwUndefined;
  Result.Weight.Value := [];
  Result.Size.LengthType := cltUndefined;
  Result.Size.Value := 0;
  Parts := SplitParameters(Trim(AValue));
  for I := 0 to High(Parts) do begin
    S := LowerCase(Parts[I]);
    if cipFontSize in ASpecified then begin  // everything after size is family
      Result.Family := Trim(Result.Family + ' ' + Parts[I]);
      Continue;
    end;
    FS := CSSFontStyleFromName(S);
    if FS <> cfsUndefined then begin
      Result.Style := FS;
      Include(ASpecified, cipFontStyle);
      Continue;
    end;
    W := CSSToFontWeight(S);
    if W.FontType <> cfwUndefined then begin
      Result.Weight := W;
      Include(ASpecified, cipFontWeight);
      Continue;
    end;
    if Pos('/', S) > 0 then S := StrBefore(S, '/');    // line-height is not supported yet
    if TryCSSToLengthValue(S, L) and (L.LengthType <> cltAuto) and (S <> '') and (S[1] in ['0'..'9', '.']) then begin
      Result.Size := L;
      Include(ASpecified, cipFontSize);
    end;
  end;
  if Result.Family <> '' then Include(ASpecified, cipFontFamily);
  // font shorthand resets style and weight to normal
  if not (cipFontStyle in ASpecified) then Result.Style := cfsNormal;
  if not (cipFontWeight in ASpecified) then Result.Weight.FontType := cfwNormal;
  ASpecified := ASpecified + [cipFontStyle, cipFontWeight];
end;

function CSSToTextDecoration(AValue: String): TCSSTextDecoration;
begin
  if Pos('underline', AValue) > 0 then Result := ctdUnderline else
  if Pos('line-through', AValue) > 0 then Result := ctdLineThrough else
  if AValue = 'none' then Result := ctdNone else
    Result := ctdUndefined;
end;

(*
  Parse whole CSS source and write it to CSSItems
*)

procedure ParseCSS(ACSS: String; ATarget: TStringList);
var
  Prop: TCSSItem;
  Sl: TStringList;
  AttCounter,
  OI,
  I, T, X: Integer;
  CurCh: Char;
  S,
  Attributes,
  Selectors: String;
  InQuotes: Boolean;
begin
  CleanCSS(ACSS);
  if Length(ACSS) = 0 then Exit;
  InQuotes := False;
  T := 1;
  AttCounter := 0;
  Sl := TStringList.Create;
  Sl.Delimiter := ',';
  Sl.StrictDelimiter := True;      // selectors can contain spaces (descendant combinator)
  for I := 1 to Length(ACSS) do begin
    CurCh := ACSS[I];
    if CurCh in ['"', ''''] then InQuotes := not InQuotes;
    if CurCh in [#10, #11, #13] then InQuotes := False;
    if not InQuotes then begin
      if CurCh = '{' then begin
        if AttCounter = 0 then begin
          Selectors := Copy(ACSS, T, I-T);
          T := I;
        end;
        Inc(AttCounter);
      end;
      if CurCh = '}' then begin
        if AttCounter = 1 then begin
          Attributes := Copy(ACSS, T+1, I-T -1);
          Sl.DelimitedText := Selectors;
          if not Trim(Selectors).StartsWith('@') then      // at-rules (@media, @font-face...) are not supported
          for X := 0 to Sl.Count -1 do begin
            S := Trim(Sl.Strings[X]);
            if S = '' then Continue;
            if ATarget.Sorted and ATarget.Find(S, OI) then ATarget.Delete(OI);
            Prop := TCSSItem.Create;
            Prop.Attributes := Attributes;
            Prop.SelectorText := S;
            Inc(CSSRuleCounter);
            Prop.Weight := CSSRuleCounter;
            ATarget.AddObject(S, Prop);
          end;
          T := I+1;
          AttCounter := 0;
        end else Dec(AttCounter);
      end;
    end;
  end;
  Sl.Free;
end;

(*
  Parse CSS selector, supported: element, *, .class, #id, :pseudo-class, descendant (space) and child (>) combinators
  Escaped characters (eg. ".hover\:bg-red-500", ".w-1\/2") are supported in names.
  Returns empty array for not supported selector.
*)
function ParseSelector(const ASelector: String; out ASpecificity: Integer): TCSSCompoundSelectors;
var
  I, Len: Integer;
  Cur: TCSSCompoundSelector;
  CurEmpty: Boolean;
  NextCombinator: TCSSCombinator;
  procedure Fail;
  begin
    Result := nil;
    ASpecificity := 0;
  end;
  function ReadIdent: String;
  begin
    Result := '';
    while I <= Len do begin
      if ASelector[I] = '\' then begin
        Inc(I);
        if I <= Len then Result := Result + ASelector[I];
        Inc(I);
        Continue;
      end;
      if ASelector[I] in [' ', '.', '#', ':', '>', '[', '+', '~', ',', '*', #9] then Break;
      if ASelector[I] = '(' then begin    // functional pseudo class eg. :not(.a) - read whole
        while (I <= Len) and (ASelector[I] <> ')') do begin
          Result := Result + ASelector[I];
          Inc(I);
        end;
      end;
      if I <= Len then Result := Result + ASelector[I];
      Inc(I);
    end;
  end;
  procedure AddArray(var A: TStringArray; const S: String);
  begin
    SetLength(A, Length(A) + 1);
    A[High(A)] := S;
  end;
  procedure PushCompound;
  begin
    if CurEmpty then Exit;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Cur;
    Cur := Default(TCSSCompoundSelector);
    CurEmpty := True;
  end;
var
  S: String;
begin
  Result := nil;
  ASpecificity := 0;
  Cur := Default(TCSSCompoundSelector);
  CurEmpty := True;
  NextCombinator := ccNone;
  I := 1;
  Len := Length(ASelector);
  while I <= Len do begin
    case ASelector[I] of
      ' ', #9: begin
        if not CurEmpty then begin
          PushCompound;
          if NextCombinator = ccNone then NextCombinator := ccDescendant;
        end;
        Inc(I);
      end;
      '>': begin
        PushCompound;
        if Length(Result) = 0 then begin Fail; Exit; end;
        NextCombinator := ccChild;
        Inc(I);
      end;
      '+', '~', '[', ',': begin   // not supported
        Fail;
        Exit;
      end;
      else begin
        if CurEmpty then begin
          if Length(Result) > 0 then begin
            if NextCombinator = ccNone then NextCombinator := ccDescendant;
            Cur.Combinator := NextCombinator;
          end;
          NextCombinator := ccNone;
        end;
        CurEmpty := False;
        case ASelector[I] of
          '.': begin
            Inc(I);
            S := ReadIdent;
            if S = '' then begin Fail; Exit; end;
            AddArray(Cur.Classes, S);
            Inc(ASpecificity, 100);
          end;
          '#': begin
            Inc(I);
            Cur.Id := ReadIdent;
            if Cur.Id = '' then begin Fail; Exit; end;
            Inc(ASpecificity, 10000);
          end;
          ':': begin
            Inc(I);
            if (I <= Len) and (ASelector[I] = ':') then begin Fail; Exit; end;  // pseudo elements are not supported
            S := LowerCase(ReadIdent);
            if S = '' then begin Fail; Exit; end;
            AddArray(Cur.Pseudos, S);
            Inc(ASpecificity, 100);
          end;
          '*': begin
            Cur.Element := CSS_UNIVERSAL_SELECTOR;
            Inc(I);
          end;
          else begin
            Cur.Element := LowerCase(ReadIdent);
            if Cur.Element = '' then begin Fail; Exit; end;
            Inc(ASpecificity);
          end;
        end;
      end;
    end;
  end;
  PushCompound;
  if NextCombinator = ccChild then Fail;   // selector ends with ">"
end;

procedure TCSSItem.CompileSelector;
begin
  if SelectorCompiled then Exit;
  SelectorCompiled := True;
  Selector := ParseSelector(SelectorText, Specificity);
  SelectorValid := Length(Selector) > 0;
end;

function CompareCSSRules(Item1, Item2: Pointer): Integer;
begin
  Result := TCSSItem(Item1).Specificity - TCSSItem(Item2).Specificity;
  if Result = 0 then Result := TCSSItem(Item1).Weight - TCSSItem(Item2).Weight;
end;

type
  TCSSUtilityCacheItem = class
    Found: Boolean;
    Declarations: String;
    Order: Integer;
  end;

var
  CSSUtilityCache: TStringList;

(*
  Resolve utility class with CSSUtilityResolver (cached)
*)
function CSSResolveUtility(const AClassName: String; out ADeclarations: String; out AOrder: Integer): Boolean;
var
  X: Integer;
  Item: TCSSUtilityCacheItem;
begin
  ADeclarations := '';
  AOrder := 0;
  if not Assigned(CSSUtilityResolver) then Exit(False);
  if CSSUtilityCache = nil then begin
    CSSUtilityCache := TCSSKeyList.Create;
    CSSUtilityCache.Sorted := True;
    CSSUtilityCache.CaseSensitive := True;
    CSSUtilityCache.OwnsObjects := True;
  end;
  if CSSUtilityCache.Find(AClassName, X) then
    Item := TCSSUtilityCacheItem(CSSUtilityCache.Objects[X])
  else begin
    Item := TCSSUtilityCacheItem.Create;
    Item.Found := CSSUtilityResolver(AClassName, Item.Declarations, Item.Order);
    CSSUtilityCache.AddObject(AClassName, Item);
  end;
  Result := Item.Found;
  ADeclarations := Item.Declarations;
  AOrder := Item.Order;
end;

procedure CSSClearUtilityCache;
begin
  if Assigned(CSSUtilityCache) then CSSUtilityCache.Clear;
end;

(*
  Convert length to pixels
  ParentLength - for percentage values
  AFontSize    - font size of node in px (for em values)
  AScale       - pixel ratio (high dpi support)
*)
function CalcCSSLength(AValue: TCSSLength; ParentLength: Integer; AFontSize: Single = CSS_DEFAULT_FONT_SIZE; AScale: Single = 1): Integer;
begin
  case AValue.LengthType of
    cltPercentage: if ParentLength < 0 then Result := 0 else Result := Round((ParentLength/100) * AValue.Value);
    cltPx: Result := Round(AValue.Value * AScale);
    cltPt: Result := Round(AValue.Value * 96 / 72 * AScale);
    cltEm: Result := Round(AValue.Value * AFontSize * AScale);
    cltRem: Result := Round(AValue.Value * CSSRootFontSize * AScale);
    cltAuto: Result := MaxInt;
    else
      Result := 0;
  end;
end;

{ THtmlSize }

function THtmlSize.TopSpace: Integer;
begin
  Result := Margin.Top + Padding.Top + Border.Top;
end;

function THtmlSize.LeftSpace: Integer;
begin
  Result := Margin.Left + Padding.Left + Border.Left;
end;

function THtmlSize.RightSpace: Integer;
begin
  Result := Margin.Right + Padding.Right + Border.Right;
end;

function THtmlSize.BottomSpace: Integer;
begin
  Result := Margin.Bottom + Padding.Bottom + Border.Bottom;
end;

function THtmlSize.RealContentWidth: Integer;
begin
  Result := ContentWidth - Padding.Left - Padding.Right - Border.Left - Border.Right;
end;

function THtmlSize.RealContentRect: TRect;
begin
  Result := Rect( ContentRect.Left + Border.Left + Padding.Left,
  ContentRect.Top + Border.Top + Padding.Top,
  ContentRect.Right - Border.Right - Padding.Right,
  ContentRect.Bottom - Border.Bottom - Padding.Bottom);
end;

{ TMatrixTransform }

constructor TMatrixTransform.Create;
begin
  Reset;
end;

constructor TMatrixTransform.Create(M0, M1, M2, M3, M4, M5: Single);
begin
  Setup(M0, M1, M2, M3, M4, M5);
end;

function TMatrixTransform.Setup(M0, M1, M2, M3, M4, M5: Single
  ): TMatrixTransform;  {$ifdef fpc}inline;{$endif}
begin
	FData[0] := M0;
	FData[1] := M1;
	FData[2] := M2;
	FData[3] := M3;
	FData[4] := M4;
	FData[5] := M5;
  Result := Self;
end;

procedure TMatrixTransform.Multiply(AMatrix: TMatrixTransform);
var
	T0, T2, T4: Single; // temps
begin
	T0 := FData[0] * AMatrix.FData[0] + FData[1] * AMatrix.FData[2];
	T2 := FData[2] * AMatrix.FData[0] + FData[3] * AMatrix.FData[2];
	T4 := FData[4] * AMatrix.FData[0] + FData[5] * AMatrix.FData[2] + AMatrix.FData[4];
	FData[1] := FData[0] * AMatrix.FData[1] + FData[1] * AMatrix.FData[3];
	FData[3] := FData[2] * AMatrix.FData[1] + FData[3] * AMatrix.FData[3];
	FData[5] := FData[4] * AMatrix.FData[1] + FData[5] * AMatrix.FData[3] + AMatrix.FData[5];
	FData[0] := T0;
	FData[2] := T2;
	FData[4] := T4;
end;

function TMatrixTransform.Reset: TMatrixTransform;
begin
  Setup(1, 0, 0, 1, 0, 0);
  Result := Self;
end;

function TMatrixTransform.FlipHorizontal: TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(-1, 0, 0, 1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.FlipVertical: TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, 0, 0, -1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Scale(AX, AY: Single): TMatrixTransform;
begin
	FData[0] := FData[0] * AX;
	FData[2] := FData[2] * AX;
	FData[4] := FData[4] * AX;
	FData[1] := FData[1] * AY;
	FData[3] := FData[3] * AY;
	FData[5] := FData[5] * AY;
	Result := Self;
end;

function TMatrixTransform.Skew(AX, AY: Single): TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, Tan(AY * CSS_DEG_RAD), Tan(AX * CSS_DEG_RAD), 1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Rotate(Angle: Single): TMatrixTransform;  // https://www.w3.org/TR/SVG/coords.html#RotationDefined
var
	Ca, Sa: Single;
	Temp: TMatrixTransform;
begin
	Math.SinCos(Angle * CSS_DEG_RAD, Sa, Ca);
	Temp := TMatrixTransform.Create(Ca, Sa, - Sa, Ca, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Translate(AX, AY: Single): TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, 0, 0, 1, AX, AY);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

procedure TMatrixTransform.Transform(var P: TFloatPoint);
var
	Tx: Single;
begin
	Tx := P.X;
	P.X := Tx * FData[0] + P.Y * FData[2] + FData[4];
	P.Y := Tx * FData[1] + P.Y * FData[3] + FData[5];
end;

{ TCSSClassList }

function TCSSClassList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TCSSClassList.GetItem(AIndex: Integer): String;
begin
  Result := FList.Strings[AIndex];
end;

function TCSSClassList.GetName: String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FList.Count - 1 do
    if I = 0 then Result := FList[I] else Result := Result + ' ' + FList[I];
end;

procedure TCSSClassList.SetName(AValue: String);
var
  Parts: TStringArray;
  I: Integer;
begin
  FList.Clear;
  Parts := SplitParameters(Trim(StringReplace(StringReplace(AValue, #9, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll])));
  for I := 0 to High(Parts) do
    Add(Parts[I]);
end;

function TCSSClassList.Contains(const AName: String): Boolean;
begin
  Result := FList.IndexOf(AName) >= 0;
end;

constructor TCSSClassList.Create;
begin
  FList :=  TStringList.Create;
  FList.CaseSensitive := True;
end;

destructor TCSSClassList.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TCSSClassList.Add(AName: String): TCSSClassList;
begin
  Result := Self;
  AName := Trim(AName);
  if (AName <> '') and (FList.IndexOf(AName) < 0) then FList.Add(AName);
end;

function TCSSClassList.Remove(AName: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  I := FList.IndexOf(AName);
  if I >= 0 then FList.Delete(I);
end;

function TCSSClassList.Replace(AFrom, ATo: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  I := FList.IndexOf(AFrom);
  if I >= 0 then begin
    if FList.IndexOf(ATo) >= 0 then FList.Delete(I)
      else FList[I] := ATo;
  end;
end;

function TCSSClassList.Toggle(AName: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  I := FList.IndexOf(AName);
  if I >= 0 then FList.Delete(I) else Add(AName);
end;

{ TCSSStyleSheet }

procedure TCSSStyleSheet.SetStyle(AValue: String);
begin
  FStyle := AValue;
  FList.Clear;
  ParseCSS(FStyle, FList);
end;

function TCSSStyleSheet.GetSelectorByName(AName: String): TCSSItem;
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    if FList[I] = AName then Exit(TCSSItem(FList.Objects[I]));
  Result := Nil;
end;

function TCSSStyleSheet.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TCSSStyleSheet.GetItem(AIndex: Integer): TCSSItem;
begin
  Result := TCSSItem(FList.Objects[AIndex]);
end;

constructor TCSSStyleSheet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FList := TStringList.Create;      // rules in order of definition
  FList.OwnsObjects := True;
end;

destructor TCSSStyleSheet.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TCSSStyleSheet.Append(const AValue: String): TCSSStyleSheet;
begin
  Result := Self;
  if AValue <> '' then
    ParseCSS(AValue, FList);
end;

{ TCSSItem }

constructor TCSSItem.Create;
begin
  Background.Color.ColorType := cctUndefined;
  Changed := False;
  Reset;
end;

destructor TCSSItem.Destroy;
begin
  CustomProps.Free;
  inherited Destroy;
end;

procedure TCSSItem.Reset;
var
  L: TCSSSide;
  procedure ResetLength(var ALength: TCSSLength; AType: TCSSLengthType = cltUndefined);
  begin
    ALength.LengthType := AType;
    ALength.Value := 0;
  end;
  procedure ResetRadius(var ARadius: TCSSBorderRadius);
  begin
    ResetLength(ARadius.Width);
    ResetLength(ARadius.Height);
  end;
begin
  AlignItems := caiStretch;
  AlignSelf := caiAuto;
  Background.Color.ColorType := cctUndefined;
  Background.Color.Value := 0;
  Background.Color.Alpha := 255;
  Background.Image := '';
  Background.Size := '';
  Background.Position := '';
  Background.RepeatMode := '';
  BoxSizing := CSSDefaultBoxSizing;
  BoxShadow := '';
  ObjectFit := '';
  ObjectPosition := '';
  Transform := '';
  TransformOrigin := '';
  Translate := '';
  Rotate := '';
  Scale := '';
  Color.ColorType := cctUndefined;
  Color.Value := 0;
  Color.Alpha := 255;
  if Assigned(CustomProps) then CustomProps.Clear;
  Cursor := crDefault;
  Display := cdtBlock;
  Float := cftNone;
  ResetLength(FlexBasis, cltAuto);
  FlexDirection := cfdRow;
  FlexGrow := 0;
  FlexShrink := 1;
  FlexWrap := cfwNoWrap;
  Font.Family := '';
  ResetLength(Font.Size);
  Font.Style := cfsUndefined;
  Font.TextDecoration := ctdUndefined;
  Font.Weight.FontType := cfwUndefined;
  Font.Weight.Value := [];
  JustifyContent := cjcFlexStart;
  Order := 0;
  Overflow := cotVisible;
  OverflowY := cotVisible;
  ZIndex := 0;
  Position := cpStatic;
  ResetRadius(RadiusTopLeft);
  ResetRadius(RadiusTopRight);
  ResetRadius(RadiusBottomLeft);
  ResetRadius(RadiusBottomRight);
  ResetLength(RowGap);
  ResetLength(ColumnGap);
  GridTemplateColumns := '';
  GridTemplateRows := '';
  GridColumnSpan := 0;
  GridRowSpan := 0;
  Opacity := 1;
  PointerEventsNone := False;
  TransitionProperty := 'all';
  TransitionTiming := 'ease';
  TransitionDuration := 0;
  TransitionDelay := 0;
  Animation := '';
  LineClamp := 0;
  AspectRatio := 0;
  ScrollbarNone := False;
  Specified := [];
  TextAlign := ctaUndefined;
  WhiteSpace := cwsNormal;
  ResetLength(Width);
  ResetLength(Height);
  ResetLength(MinWidth);
  ResetLength(MinHeight);
  ResetLength(MaxWidth);
  ResetLength(MaxHeight);
  ResetLength(Top);
  ResetLength(Left);
  ResetLength(Right);
  ResetLength(Bottom);
  for L := Low(TCSSSide) to High(TCSSSide) do begin
    ResetLength(Margin[L]);
    ResetLength(Padding[L]);
    Border[L].Style := cbsNone;
    Border[L].Color.ColorType := cctCurrentColor;
    Border[L].Color.Value := 0;
    Border[L].Color.Alpha := 255;
    ResetLength(Border[L].Width, cltPx);
    Border[L].Width.Value := 3;  // medium
  end;
end;

(*
  Parse css property separated with ";". Eg.: background-color:red;margin-top: 10px;
*)
procedure TCSSItem.Parse(const AValue: String);
var
  PropertyList: TStringlist;
  S, PName: String;
  I: Integer;
begin
  PropertyList := DivideToStringList(AValue, ';');
  for I := 0 to PropertyList.Count-1 do begin
    S := PropertyList.Strings[I];
    PName := Copy(S, 1, Pos(':', S) - 1);
    S := Copy(S, Length(PName) + 2, Length(S));
    if (s = '') or (PName = '') then Continue;
    AddProperty(AnsiLowerCase(PName), S);
  end;
  Changed := True;
  PropertyList.Free;
end;

procedure TCSSItem.ParseFromStyleSheet(AStyleSheet: TCSSStyleSheet; const APropertyName: String);
var
  cs: TCSSItem;
begin
  cs := AStyleSheet.Selector[APropertyName];
  if Assigned(cs) then Self.Parse(cs.Attributes);
end;

(*
  Expand 1-4 values shorthand to top, right, bottom, left
  https://developer.mozilla.org/en-US/docs/Web/CSS/Shorthand_properties#tricky_edge_cases
*)
function ExpandSides(const AParts: TStringArray; out ATop, ARight, ABottom, ALeft: String): Boolean;
begin
  Result := True;
  case Length(AParts) of
    1: begin ATop := AParts[0]; ARight := AParts[0]; ABottom := AParts[0]; ALeft := AParts[0]; end;
    2: begin ATop := AParts[0]; ARight := AParts[1]; ABottom := AParts[0]; ALeft := AParts[1]; end;
    3: begin ATop := AParts[0]; ARight := AParts[1]; ABottom := AParts[2]; ALeft := AParts[1]; end;
    4: begin ATop := AParts[0]; ARight := AParts[1]; ABottom := AParts[2]; ALeft := AParts[3]; end;
    else Result := False;
  end;
end;

procedure TCSSItem.AddProperty(AName: String; AValue: String);
var
  Parts: TStringArray;
  T, R, B, L: String;
  I: Integer;
  F: Single;
  L1: TCSSLength;
begin
  AName := Trim(AName);
  AValue := Trim(AValue);
  I := Pos('!important', LowerCase(AValue));        // priority is not supported, ignore it
  if I > 0 then AValue := Trim(Copy(AValue, 1, I - 1));
  if AValue = '' then Exit;
  Parts := SplitParameters(AValue);
  if (AName = 'margin') or (AName = 'padding') or (AName = 'border-width') or (AName = 'border-style') or (AName = 'border-color') then begin
    if ExpandSides(Parts, T, R, B, L) then begin
      if AName.StartsWith('border-') then begin
        AName := Copy(AName, 8, MaxInt);  // width, style, color
        AddParsedProperty('border-top-' + AName, T);
        AddParsedProperty('border-right-' + AName, R);
        AddParsedProperty('border-bottom-' + AName, B);
        AddParsedProperty('border-left-' + AName, L);
      end else begin
        AddParsedProperty(AName + '-top', T);
        AddParsedProperty(AName + '-right', R);
        AddParsedProperty(AName + '-bottom', B);
        AddParsedProperty(AName + '-left', L);
      end;
    end;
  end else
  if AName = 'inset' then begin
    if ExpandSides(Parts, T, R, B, L) then begin
      AddParsedProperty('top', T);
      AddParsedProperty('right', R);
      AddParsedProperty('bottom', B);
      AddParsedProperty('left', L);
    end;
  end else
  if (AName = 'border') then begin
    AddParsedProperty(AName+ '-top', AValue);
    AddParsedProperty(AName+ '-left', AValue);
    AddParsedProperty(AName+ '-bottom', AValue);
    AddParsedProperty(AName+ '-right', AValue);
  end else
  if (AName = 'border-radius') then begin
    AValue := StrBefore(AValue + '/', '/');         // elliptical corners "a / b" are not supported yet
    Parts := SplitParameters(Trim(AValue));
    // order: top-left, top-right, bottom-right, bottom-left
    if ExpandSides(Parts, T, R, B, L) then begin
      AddParsedProperty('border-top-left-radius', T);
      AddParsedProperty('border-top-right-radius', R);
      AddParsedProperty('border-bottom-right-radius', B);
      AddParsedProperty('border-bottom-left-radius', L);
    end;
  end else
  if AName = 'gap' then begin
    AddParsedProperty('row-gap', Parts[0]);
    if Length(Parts) > 1 then AddParsedProperty('column-gap', Parts[1])
      else AddParsedProperty('column-gap', Parts[0]);
  end else
  if AName = 'flex' then begin   // https://developer.mozilla.org/en-US/docs/Web/CSS/flex
    if AValue = 'none' then begin
      FlexGrow := 0; FlexShrink := 0; FlexBasis := CSSToLength('auto');
    end else
    if AValue = 'auto' then begin
      FlexGrow := 1; FlexShrink := 1; FlexBasis := CSSToLength('auto');
    end else
    if AValue = 'initial' then begin
      FlexGrow := 0; FlexShrink := 1; FlexBasis := CSSToLength('auto');
    end else begin
      FlexGrow := 0; FlexShrink := 1; FlexBasis := CSSToLength('0');
      I := 0;
      if (I < Length(Parts)) and CSSStrToFloat(Parts[I], F) then begin
        FlexGrow := F;
        Inc(I);
        if (I < Length(Parts)) and CSSStrToFloat(Parts[I], F) then begin
          FlexShrink := F;
          Inc(I);
        end;
      end;
      if I < Length(Parts) then FlexBasis := CSSToLength(Parts[I]);
    end;
  end else
  if AName = 'flex-flow' then begin
    for I := 0 to High(Parts) do
      if Parts[I].StartsWith('wrap') or (Parts[I] = 'nowrap') then AddParsedProperty('flex-wrap', Parts[I])
        else AddParsedProperty('flex-direction', Parts[I]);
  end else
  if (AName = 'background') then begin   // [image] [position[/size]] [repeat] [color]
    Background.Image := 'none';
    Background.Color.ColorType := cctUndefined;
    Background.Size := '';
    Background.Position := '';
    Background.RepeatMode := '';
    F := 0;    // 1 = after "/" (size)
    for I := 0 to High(Parts) do begin
      T := LowerCase(Parts[I]);
      if T = '/' then begin
        F := 1;
        Background.Size := '';
      end else
      if (F = 1) and (TryCSSToLengthValue(T, L1) or (T = 'cover') or (T = 'contain')) then
        Background.Size := Trim(Background.Size + ' ' + T)
      else
      if T.StartsWith('url(') or T.StartsWith('linear-gradient(') or T.StartsWith('var(') then
        Background.Image := Parts[I]
      else if (T = 'repeat') or (T = 'no-repeat') or (T = 'repeat-x') or (T = 'repeat-y') then
        Background.RepeatMode := T
      else if CSSToColor(T).ColorType <> cctUndefined then
        Background.Color := CSSToColor(T)
      else if Pos('/', T) > 0 then begin
        Background.Position := Trim(Background.Position + ' ' + StrBefore(T, '/'));
        Background.Size := StrAfter(T, '/');
      end else if (T = 'cover') or (T = 'contain') then
        Background.Size := T
      else
        Background.Position := Trim(Background.Position + ' ' + T);
    end;
  end else
  if (AName = 'overflow') then begin     // overflow: x [y]
    AddParsedProperty('overflow-x', Parts[0]);
    if Length(Parts) > 1 then AddParsedProperty('overflow-y', Parts[1]) else AddParsedProperty('overflow-y', Parts[0]);
  end else AddParsedProperty(AName, AValue);
end;

function CSSToFontSize(const AValue: String): TCSSLength;  // https://developer.mozilla.org/en-US/docs/Web/CSS/font-size
const
  Names: array[0..6] of String = ('xx-small', 'x-small', 'small', 'medium', 'large', 'x-large', 'xx-large');
  Sizes: array[0..6] of Integer = (9, 10, 13, 16, 18, 24, 32);
var
  I: Integer;
begin
  for I := 0 to High(Names) do
    if Names[I] = AValue then begin
      Result.LengthType := cltPx;
      Result.Value := Sizes[I];
      Exit;
    end;
  Result.LengthType := cltEm;
  if AValue = 'smaller' then Result.Value := 0.833 else
  if AValue = 'larger' then Result.Value := 1.2 else
    Result := CSSToLength(AValue);
end;

procedure TCSSItem.AddParsedProperty(AName: String; AValue: String);
  procedure SetBorderPart(ASide: TCSSSide; const APart: String);
  begin
    if APart = 'width' then Border[ASide].Width := CSSToBorderWidth(AValue) else
    if APart = 'style' then CSSToBorderStyle(AValue, Border[ASide].Style) else
    if APart = 'color' then Border[ASide].Color := CSSToColor(AValue);
  end;
  function InheritedPropOf(const AProp: String; out AInherited: TCSSInheritedProp): Boolean;
  begin
    Result := True;
    if AProp = 'color' then AInherited := cipColor else
    if AProp = 'font-size' then AInherited := cipFontSize else
    if AProp = 'font-family' then AInherited := cipFontFamily else
    if AProp = 'font-style' then AInherited := cipFontStyle else
    if AProp = 'font-weight' then AInherited := cipFontWeight else
    if AProp = 'text-decoration' then AInherited := cipTextDecoration else
    if AProp = 'text-align' then AInherited := cipTextAlign else
    if AProp = 'white-space' then AInherited := cipWhiteSpace else
      Result := False;
  end;
var
  Side: TCSSSide;
  Prop: TCSSInheritedProp;
  FontSpecified: TCSSInheritedProps;
  S: String;
begin
  if AValue = '' then Exit;
  if (Length(AName) > 2) and (AName[1] = '-') and (AName[2] = '-') then begin   // custom property
    if CustomProps = nil then CustomProps := TStringList.Create;
    CustomProps.Values[AName] := AValue;
    Exit;
  end;
  if AName = 'text-decoration-line' then AName := 'text-decoration';
  if InheritedPropOf(AName, Prop) then begin
    if (AValue = 'inherit') or (AValue = 'unset') or ((Prop = cipColor) and SameText(AValue, 'currentcolor')) then begin
      Exclude(Specified, Prop);
      Exit;
    end;
    Include(Specified, Prop);
  end;
  case AName[1] of
    'a':
      if AName = 'animation' then
        Animation := LowerCase(Trim(AValue))
      else
      if AName = 'aspect-ratio' then
        AspectRatio := CSSToAspectRatio(AValue)
      else
      if AName = 'align-items' then
        AlignItems := CSSToAlignItems(AValue)
      else
      if AName = 'align-self' then
        AlignSelf := CSSToAlignItems(AValue, caiAuto);
    'b':
      if AName = 'background-color' then
        Background.Color := CSSToColor(AValue)
      else
      if AName = 'background-image' then
        Background.Image := AValue
      else
      if AName = 'background-size' then
        Background.Size := AValue
      else
      if AName = 'background-position' then
        Background.Position := AValue
      else
      if AName = 'background-repeat' then
        Background.RepeatMode := AValue
      else
      if AName = 'box-shadow' then
        BoxShadow := AValue
      else
      if AName = 'box-sizing' then begin
        if AValue = 'border-box' then BoxSizing := cbxBorderBox else BoxSizing := cbxContentBox;
      end else
      if AName = 'bottom' then
        Bottom := CSSToLength(AValue)
      else
      if AName.StartsWith('border-') then begin
        S := Copy(AName, 8, MaxInt);         // top, top-width, top-left-radius ...
        if S = 'top-left-radius' then RadiusTopLeft := CSSToBorderRadius(AValue) else
        if S = 'top-right-radius' then RadiusTopRight := CSSToBorderRadius(AValue) else
        if S = 'bottom-left-radius' then RadiusBottomLeft := CSSToBorderRadius(AValue) else
        if S = 'bottom-right-radius' then RadiusBottomRight := CSSToBorderRadius(AValue) else
        for Side := Low(TCSSSide) to High(TCSSSide) do begin
          case Side of
            csTop: if not S.StartsWith('top') then Continue else S := Copy(S, 4, MaxInt);
            csLeft: if not S.StartsWith('left') then Continue else S := Copy(S, 5, MaxInt);
            csBottom: if not S.StartsWith('bottom') then Continue else S := Copy(S, 7, MaxInt);
            csRight: if not S.StartsWith('right') then Continue else S := Copy(S, 6, MaxInt);
          end;
          if S = '' then Border[Side] := CSSToBorder(AValue)
            else SetBorderPart(Side, Copy(S, 2, MaxInt));   // "-width" -> "width"
          Break;
        end;
      end;
    'c':
      if AName = 'color' then
        Color := CSSToColor(AValue)
      else
      if AName = 'cursor' then
        Cursor := CSSToCursor(AValue)
      else
      if AName = 'column-gap' then
        ColumnGap := CSSToLength(AValue);
    'd':
      if AName = 'display' then
        Display := CSSToDisplay(AValue);
    'f':
      if AName = 'flex-grow' then
        FlexGrow := Max(0, CSSStrToFloatDef(AValue, 0))
      else
      if AName = 'flex-shrink' then
        FlexShrink := Max(0, CSSStrToFloatDef(AValue, 1))
      else
      if AName = 'flex-basis' then
        FlexBasis := CSSToLength(AValue)
      else
      if AName = 'flex-direction' then
        FlexDirection := CSSToFlexDirection(AValue)
      else
      if AName = 'flex-wrap' then
        FlexWrap := CSSToFlexWrap(AValue)
      else
      if AName = 'float' then
        Float := CSSToFloat(AValue)
      else
      if AName = 'font' then begin
        Font := CSSToFont(AValue, FontSpecified);
        Specified := Specified + FontSpecified;
      end else
      if AName = 'font-size' then
        Font.Size := CSSToFontSize(AValue)
      else
      if AName = 'font-family' then
        Font.Family := AValue
      else
      if AName = 'font-style' then
        Font.Style := CSSFontStyleFromName(AValue)
      else
      if AName = 'font-weight' then
        Font.Weight := CSSToFontWeight(AValue);
    'g':
      if AName = 'grid-template-columns' then
        GridTemplateColumns := AValue
      else
      if AName = 'grid-template-rows' then
        GridTemplateRows := AValue
      else
      if AName = 'grid-column' then
        GridColumnSpan := CSSToGridSpan(AValue)
      else
      if AName = 'grid-row' then
        GridRowSpan := CSSToGridSpan(AValue);
    'h':
      if AName = 'height' then
        Height := CSSToLength(AValue);
    'j':
      if AName = 'justify-content' then
        JustifyContent := CSSToJustifyContent(AValue);
    'l':
      if AName = 'left' then
        Left := CSSToLength(AValue)
      else
      if AName = 'line-clamp' then
        LineClamp := Max(0, StrToIntDef(Trim(AValue), 0));
    'm':
      if AName = 'margin-left' then
        Margin[csLeft] := CSSToLength(AValue)
      else
      if AName = 'margin-top' then
        Margin[csTop] := CSSToLength(AValue)
      else
      if AName = 'margin-bottom' then
        Margin[csBottom] := CSSToLength(AValue)
      else
      if AName = 'margin-right' then
        Margin[csRight] := CSSToLength(AValue)
      else
      if AName = 'min-width' then
        MinWidth := CSSToLength(AValue)
      else
      if AName = 'min-height' then
        MinHeight := CSSToLength(AValue)
      else
      if AName = 'max-width' then
        MaxWidth := CSSToLength(AValue)
      else
      if AName = 'max-height' then
        MaxHeight := CSSToLength(AValue);
    'o':
      if AName = 'opacity' then
        Opacity := CSSToOpacity(AValue)
      else
      if AName = 'object-fit' then
        ObjectFit := LowerCase(AValue)
      else
      if AName = 'object-position' then
        ObjectPosition := AValue
      else
      if AName = 'overflow-x' then
        Overflow := CSSToOverflowType(AValue)
      else
      if AName = 'overflow-y' then
        OverflowY := CSSToOverflowType(AValue)
      else
      if AName = 'order' then
        Order := StrToIntDef(AValue, 0);
    'p':
      if AName = 'pointer-events' then
        PointerEventsNone := SameText(Trim(AValue), 'none')
      else
      if AName = 'padding-left' then
        Padding[csLeft] := CSSToLength(AValue)
      else
      if AName = 'padding-top' then
        Padding[csTop] := CSSToLength(AValue)
      else
      if AName = 'padding-bottom' then
        Padding[csBottom] := CSSToLength(AValue)
      else
      if AName = 'padding-right' then
        Padding[csRight] := CSSToLength(AValue)
      else
      if AName = 'position' then
        Position := CSSToPosition(AValue);
    's':
      if AName = 'scrollbar-width' then
        ScrollbarNone := SameText(Trim(AValue), 'none')
      else
      if AName = 'scale' then
        Scale := AValue;
    'r':
      if AName = 'rotate' then
        Rotate := AValue
      else
      if AName = 'right' then
        Right := CSSToLength(AValue)
      else
      if AName = 'row-gap' then
        RowGap := CSSToLength(AValue);
    't':
      if AName = 'top' then
        Top := CSSToLength(AValue)
      else
      if AName = 'transition' then
        ParseTransition(Self, AValue)
      else
      if AName = 'transition-property' then
        TransitionProperty := LowerCase(Trim(AValue))
      else
      if AName = 'transition-duration' then
        TransitionDuration := CSSToTime(AValue)
      else
      if AName = 'transition-delay' then
        TransitionDelay := CSSToTime(AValue)
      else
      if AName = 'transition-timing-function' then
        TransitionTiming := LowerCase(Trim(AValue))
      else
      if AName = 'transform' then
        Transform := AValue
      else
      if AName = 'transform-origin' then
        TransformOrigin := AValue
      else
      if AName = 'translate' then
        Translate := AValue
      else
      if AName = 'text-align' then
        TextAlign := CSSToTextAlign(AValue)
      else
      if AName = 'text-decoration' then
        Font.TextDecoration := CSSToTextDecoration(AValue);
    'z':
      if AName = 'z-index' then
        ZIndex := StrToIntDef(AValue, 0);
    'w':
      if AName = 'width' then
        Width := CSSToLength(AValue)
      else
      if AName = 'white-space' then begin
        if (AValue = 'nowrap') or (AValue = 'pre') then WhiteSpace := cwsNoWrap else WhiteSpace := cwsNormal;
      end;
  end;
end;

(*
  Key of properties which affect layout: when only other properties are changed (colors, shadows,
  transforms, opacity), node is only repainted
*)
function TCSSItem.LayoutKey: String;
var
  S: TCSSSide;
  function L(const ALength: TCSSLength): String; inline;
  begin
    Result := FloatToStr(ALength.Value) + Chr(Ord('a') + Ord(ALength.LengthType)) + ',';
  end;
begin
  Result := Format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%f,%d,%d,', [Ord(Display), Ord(Position), Ord(Float),
    Ord(BoxSizing), Ord(Overflow), Ord(OverflowY), Ord(FlexDirection), Ord(FlexWrap), Ord(JustifyContent), Ord(AlignItems),
    Ord(AlignSelf), Order, Ord(WhiteSpace), LineClamp, GridColumnSpan, GridRowSpan, GridTemplateColumns, GridTemplateRows,
    FloatToStr(FlexGrow), FloatToStr(FlexShrink), Font.Family, AspectRatio, Ord(Font.Style), Ord(Font.Weight.FontType)]) +
    L(FlexBasis) + L(RowGap) + L(ColumnGap) + L(Width) + L(Height) + L(MinWidth) + L(MinHeight) + L(MaxWidth) + L(MaxHeight) +
    L(Top) + L(Left) + L(Right) + L(Bottom) + L(Font.Size) + IntToStr(Integer(Font.Weight.Value));
  for S := Low(TCSSSide) to High(TCSSSide) do
    Result := Result + L(Margin[S]) + L(Padding[S]) + L(Border[S].Width) + IntToStr(Ord(Border[S].Style));
end;

function TCSSItem.PaintKey: String;
var
  S: TCSSSide;
  function C(const AColor: TCSSColor): String; inline;
  begin
    Result := IntToStr(AColor.Value) + ':' + IntToStr(AColor.Alpha) + ':' + IntToStr(Ord(AColor.ColorType)) + ',';
  end;
  function L(const ALength: TCSSLength): String; inline;
  begin
    Result := FloatToStr(ALength.Value) + Chr(Ord('a') + Ord(ALength.LengthType)) + ',';
  end;
begin
  Result := C(Background.Color) + C(Color) + Background.Image + '|' + Background.Size + '|' + Background.Position + '|' +
    Background.RepeatMode + '|' + BoxShadow + '|' + Transform + '|' + TransformOrigin + '|' + Translate + '|' + Rotate + '|' +
    Scale + '|' + FloatToStr(Opacity) + '|' + ObjectFit + '|' + ObjectPosition + '|' +
    Format('%d,%d,%d,%d,', [Ord(TextAlign), Ord(Font.TextDecoration), ZIndex, Ord(ScrollbarNone)]) +
    L(RadiusTopLeft.Width) + L(RadiusTopLeft.Height) + L(RadiusTopRight.Width) + L(RadiusTopRight.Height) +
    L(RadiusBottomLeft.Width) + L(RadiusBottomLeft.Height) + L(RadiusBottomRight.Width) + L(RadiusBottomRight.Height);
  for S := Low(TCSSSide) to High(TCSSSide) do
    Result := Result + C(Border[S].Color);
  if Assigned(CustomProps) then Result := Result + CustomProps.Text;
end;

procedure TCSSItem.Assign(Source: TPersistent);
var
  Src: TCSSItem;
  I: TCSSSide;
begin
  if Source = Nil then Exit;
	if Source is TCSSItem then begin
		Src := TCSSItem(Source);
    Attributes := Src.Attributes;
    AlignSelf := Src.AlignSelf;
    AlignItems := Src.AlignItems;
    Background := Src.Background;
    BoxSizing := Src.BoxSizing;
    BoxShadow := Src.BoxShadow;
    ObjectFit := Src.ObjectFit;
    ObjectPosition := Src.ObjectPosition;
    Transform := Src.Transform;
    TransformOrigin := Src.TransformOrigin;
    Translate := Src.Translate;
    Rotate := Src.Rotate;
    Scale := Src.Scale;
    Color := Src.Color;
    Cursor := Src.Cursor;
    Display := Src.Display;
    Font := Src.Font;
    Float := Src.Float;
    FlexBasis := Src.FlexBasis;
    FlexDirection := Src.FlexDirection;
    FlexGrow := Src.FlexGrow;
    FlexShrink := Src.FlexShrink;
    FlexWrap := Src.FlexWrap;
    for I := Low(TCSSSide) to High(TCSSSide) do begin
      Border[I] := Src.Border[I];
      Margin[I] := Src.Margin[I];
      Padding[I] := Src.Padding[I];
    end;
    JustifyContent := Src.JustifyContent;
    Order := Src.Order;
    Overflow := Src.Overflow;
    OverflowY := Src.OverflowY;
    ZIndex := Src.ZIndex;
    Position := Src.Position;
    RadiusTopLeft := Src.RadiusTopLeft;
    RadiusTopRight := Src.RadiusTopRight;
    RadiusBottomLeft := Src.RadiusBottomLeft;
    RadiusBottomRight := Src.RadiusBottomRight;
    RowGap := Src.RowGap;
    ColumnGap := Src.ColumnGap;
    GridTemplateColumns := Src.GridTemplateColumns;
    GridTemplateRows := Src.GridTemplateRows;
    GridColumnSpan := Src.GridColumnSpan;
    GridRowSpan := Src.GridRowSpan;
    Opacity := Src.Opacity;
    PointerEventsNone := Src.PointerEventsNone;
    TransitionProperty := Src.TransitionProperty;
    TransitionTiming := Src.TransitionTiming;
    TransitionDuration := Src.TransitionDuration;
    TransitionDelay := Src.TransitionDelay;
    Animation := Src.Animation;
    LineClamp := Src.LineClamp;
    ScrollbarNone := Src.ScrollbarNone;
    AspectRatio := Src.AspectRatio;
    Specified := Src.Specified;
    TextAlign :=  Src.TextAlign;
    WhiteSpace := Src.WhiteSpace;
    Height := Src.Height;
    Width := Src.Width;
    MinHeight := Src.MinHeight;
    MinWidth := Src.MinWidth;
    MaxHeight := Src.MaxHeight;
    MaxWidth := Src.MaxWidth;
    Top := Src.Top;
    Left := Src.Left;
    Right := Src.Right;
    Bottom := Src.Bottom;
    Weight := Src.Weight;
    Specificity := Src.Specificity;
    SelectorText := Src.SelectorText;
    if Assigned(Src.CustomProps) then begin
      if CustomProps = nil then CustomProps := TStringList.Create;
      CustomProps.Assign(Src.CustomProps);
    end else
    if Assigned(CustomProps) then CustomProps.Clear;
	end else
		inherited Assign(Source);
end;

(*
  Merge defined (non default) color, margin and padding values
*)
procedure TCSSItem.Merge(AValue: TCSSItem);
var
  I: TCSSSide;
begin
  if AValue.Color.ColorType <> cctUndefined then Color := AValue.Color;
  if AValue.Background.Color.ColorType <> cctUndefined then Background := AValue.Background;
  for I := Low(TCSSSide) to High(TCSSSide) do begin
    if AValue.Margin[I].LengthType <> cltUndefined then Margin[I] := AValue.Margin[I];
    if AValue.Padding[I].LengthType <> cltUndefined then Padding[I] := AValue.Padding[I];
  end;
end;

{ THtmlNode }


(*
  Split inline style to names and values
*)
procedure SplitDeclarations(const AStyle: String; ANames, AValues: TStringList);
var
  List: TStringList;
  I: Integer;
  S, N: String;
begin
  List := DivideToStringList(AStyle, ';');
  try
    for I := 0 to List.Count - 1 do begin
      S := List[I];
      N := LowerCase(Trim(Copy(S, 1, Pos(':', S) - 1)));
      if N = '' then Continue;
      ANames.Add(N);
      AValues.Add(Trim(Copy(S, Pos(':', S) + 1, MaxInt)));
    end;
  finally
    List.Free;
  end;
end;

(*
  Set or remove (empty AValue) property in inline style
*)
procedure THtmlNode.SetStyleValue(AName: String; AValue: String);
var
  Names, Values: TStringList;
  I: Integer;
  S: String;
begin
  AName := LowerCase(Trim(AName));
  if AName = '' then Exit;
  Names := TStringList.Create;
  Values := TStringList.Create;
  try
    SplitDeclarations(FInlineStyle, Names, Values);
    I := Names.IndexOf(AName);
    if I >= 0 then begin
      if Trim(AValue) = '' then begin
        Names.Delete(I);
        Values.Delete(I);
      end else
        Values[I] := Trim(AValue);
    end else
    if Trim(AValue) <> '' then begin
      Names.Add(AName);
      Values.Add(Trim(AValue));
    end;
    S := '';
    for I := 0 to Names.Count - 1 do
      S := S + Names[I] + ':' + Values[I] + ';';
    InlineStyle := S;
  finally
    Names.Free;
    Values.Free;
  end;
end;

(*
  Painting of backgrounds and borders

  Straight parts (background, border sides) are painted by FillRect, corners (border-radius, joins of
  borders) are rasterized with antialiasing into small bitmaps with alpha channel. Corner bitmaps are
  cached globally (same corners of different nodes share bitmap). Backgrounds with gradient, image or
  alpha color are rendered to one cached bitmap per node.
*)
type
  TCSSSampleKind = (cskOutside, cskBackground, cskTop, cskLeft, cskBottom, cskRight);
  // rounded padding box of nearest painted parent with overflow clipping (children touching its corners are rounded)
  TCSSClipCorners = record
    Active: Boolean;
    Box: TRect;
    RX, RY: array[0..3] of Integer;
  end;

var
  CSSCornerCache: TStringList;          // key -> TBitmap
  CSSShadowCache: TStringList;          // key -> TCSSShadowSlices
  CSSPaintGeneration: Integer = 0;      // incremented when styles or layout are changed (cache of transformed nodes)
  CSSImageCache: TStringList;           // url -> TCSSImageData
  CSSPaintClip: TCSSClipCorners;        // valid only while painting

const
  CSS_CORNER_CACHE_LIMIT = 2000;

function InRoundRect(L, T, R, B: Single; const RX, RY: array of Single; X, Y: Single): Boolean;
begin
  Result := False;
  if (X < L) or (X >= R) or (Y < T) or (Y >= B) then Exit;
  if (RX[0] > 0) and (RY[0] > 0) and (X < L + RX[0]) and (Y < T + RY[0]) then
    Exit(Sqr((X - L - RX[0]) / RX[0]) + Sqr((Y - T - RY[0]) / RY[0]) <= 1);
  if (RX[1] > 0) and (RY[1] > 0) and (X > R - RX[1]) and (Y < T + RY[1]) then
    Exit(Sqr((X - R + RX[1]) / RX[1]) + Sqr((Y - T - RY[1]) / RY[1]) <= 1);
  if (RX[2] > 0) and (RY[2] > 0) and (X > R - RX[2]) and (Y > B - RY[2]) then
    Exit(Sqr((X - R + RX[2]) / RX[2]) + Sqr((Y - B + RY[2]) / RY[2]) <= 1);
  if (RX[3] > 0) and (RY[3] > 0) and (X < L + RX[3]) and (Y > B - RY[3]) then
    Exit(Sqr((X - L - RX[3]) / RX[3]) + Sqr((Y - B + RY[3]) / RY[3]) <= 1);
  Result := True;
end;

function InOuterShape(const S: TCSSPaintShape; X, Y: Single): Boolean; inline;
begin
  Result := InRoundRect(S.L, S.T, S.R, S.B, S.RX, S.RY, X, Y);
end;

(*
  Inner shape (padding box): inner radius = outer radius - border width, https://www.w3.org/TR/css-backgrounds-3/#corner-shaping
*)
function InInnerShape(const S: TCSSPaintShape; X, Y: Single): Boolean;
var
  IRX, IRY: array[0..3] of Single;
begin
  IRX[0] := Max(0, S.RX[0] - S.BW[csLeft]);   IRY[0] := Max(0, S.RY[0] - S.BW[csTop]);
  IRX[1] := Max(0, S.RX[1] - S.BW[csRight]);  IRY[1] := Max(0, S.RY[1] - S.BW[csTop]);
  IRX[2] := Max(0, S.RX[2] - S.BW[csRight]);  IRY[2] := Max(0, S.RY[2] - S.BW[csBottom]);
  IRX[3] := Max(0, S.RX[3] - S.BW[csLeft]);   IRY[3] := Max(0, S.RY[3] - S.BW[csBottom]);
  Result := InRoundRect(S.L + S.BW[csLeft], S.T + S.BW[csTop], S.R - S.BW[csRight], S.B - S.BW[csBottom], IRX, IRY, X, Y);
end;

(*
  Classify point of shape. Point in border area belongs to side with smaller distance / border width,
  so join of two borders goes from outer corner to inner corner and side with zero width takes nothing.
  ACorner: candidates sides (0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left), -1 = by quadrant
*)
function SampleShape(const S: TCSSPaintShape; ACorner: Integer; X, Y: Single): TCSSSampleKind;
var
  HSide, VSide: TCSSSide;
  DH, DV: Single;
begin
  if not InOuterShape(S, X, Y) then Exit(cskOutside);
  if InInnerShape(S, X, Y) then Exit(cskBackground);
  if ACorner < 0 then begin
    if X < (S.L + S.R) / 2 then ACorner := 0 else ACorner := 1;
    if Y >= (S.T + S.B) / 2 then ACorner := 3 - ACorner;
  end;
  if ACorner in [0, 3] then HSide := csLeft else HSide := csRight;
  if ACorner in [0, 1] then VSide := csTop else VSide := csBottom;
  if S.BW[HSide] > 0 then begin
    if HSide = csLeft then DH := (X - S.L) / S.BW[HSide] else DH := (S.R - X) / S.BW[HSide];
  end else
    DH := MaxSingle;
  if S.BW[VSide] > 0 then begin
    if VSide = csTop then DV := (Y - S.T) / S.BW[VSide] else DV := (S.B - Y) / S.BW[VSide];
  end else
    DV := MaxSingle;
  if (DH = MaxSingle) and (DV = MaxSingle) then Exit(cskBackground);
  if DV <= DH then begin
    if VSide = csTop then Result := cskTop else Result := cskBottom;
  end else begin
    if HSide = csLeft then Result := cskLeft else Result := cskRight;
  end;
end;

function IntfImageToBitmap(AImage: TLazIntfImage): TBitmap;
begin
  {$ifdef windows}
  Result := TCSSWinBitmap.Create;
  Result.LoadFromIntfImage(AImage);
  TCSSWinBitmap(Result).Prepare(AImage);
  {$else}
  Result := TBitmap.Create;
  Result.LoadFromIntfImage(AImage);
  {$endif}
end;

type
  { TCSSPixelWriter - writes 32 bit pixels directly in native format of TLazIntfImage }
  TCSSPixelWriter = record
    Img: TLazIntfImage;
    Fast: Boolean;
    ShiftR, ShiftG, ShiftB, ShiftA: Byte;     // shifts of channels in LongWord
    Line: PLongWord;
    Y: Integer;
  end;

function NewAlphaImage(AWidth, AHeight: Integer): TLazIntfImage;
begin
  Result := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
  Result.SetSize(AWidth, AHeight);
end;

function PixelWriter(AImage: TLazIntfImage): TCSSPixelWriter;
  function Shift(AShift: Byte): Byte;
  begin
    if AImage.DataDescription.ByteOrder = DefaultByteOrder then Result := AShift else Result := 24 - AShift;
  end;
begin
  Result.Img := AImage;
  with AImage.DataDescription do begin
    Result.Fast := (Format = ricfRGBA) and (BitsPerPixel = 32) and (Depth = 32) and (RedPrec = 8) and (GreenPrec = 8) and
      (BluePrec = 8) and (AlphaPrec = 8) and (RedShift mod 8 = 0) and (GreenShift mod 8 = 0) and (BlueShift mod 8 = 0) and
      (AlphaShift mod 8 = 0) and (LineOrder = riloTopToBottom);
    if Result.Fast then begin
      Result.ShiftR := Shift(RedShift);
      Result.ShiftG := Shift(GreenShift);
      Result.ShiftB := Shift(BlueShift);
      Result.ShiftA := Shift(AlphaShift);
    end;
  end;
  Result.Line := nil;
  Result.Y := -1;
end;

procedure WriterLine(var W: TCSSPixelWriter; Y: Integer); inline;
begin
  W.Y := Y;
  if W.Fast then W.Line := PLongWord(W.Img.GetDataLineStart(Y));
end;

(*
  Write pixel with not premultiplied color 0..255
*)
procedure WritePixel(var W: TCSSPixelWriter; X: Integer; R, G, B, A: Byte); inline;
begin
  if W.Fast then
    W.Line[X] := (LongWord(R) shl W.ShiftR) or (LongWord(G) shl W.ShiftG) or (LongWord(B) shl W.ShiftB) or (LongWord(A) shl W.ShiftA)
  else
    W.Img.Colors[X, W.Y] := FPColor(R * 257, G * 257, B * 257, A * 257);
end;

{$ifdef windows}
{ TCSSWinBitmap }

procedure TCSSWinBitmap.Prepare(AImage: TLazIntfImage);
var
  BI: TBitmapInfo;
  Bits: Pointer;
  P: PLongWord;
  Rd: TCSSPixelWriter;
  X, Y: Integer;
  V, A, R, G, B: LongWord;
  C: TFPColor;
begin
  if (AImage.Width <= 0) or (AImage.Height <= 0) then Exit;
  FillChar(BI, SizeOf(BI), 0);
  BI.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  BI.bmiHeader.biWidth := AImage.Width;
  BI.bmiHeader.biHeight := -AImage.Height;      // top-down
  BI.bmiHeader.biPlanes := 1;
  BI.bmiHeader.biBitCount := 32;
  BI.bmiHeader.biCompression := BI_RGB;
  Bits := nil;
  FDib := CreateDIBSection(0, BI, DIB_RGB_COLORS, Bits, 0, 0);
  if FDib = 0 then Exit;
  if Bits = nil then begin
    DeleteObject(FDib);
    FDib := 0;
    Exit;
  end;
  // premultiplied BGRA
  Rd := PixelWriter(AImage);
  P := Bits;
  for Y := 0 to AImage.Height - 1 do begin
    WriterLine(Rd, Y);
    for X := 0 to AImage.Width - 1 do begin
      if Rd.Fast then begin
        V := Rd.Line[X];
        A := (V shr Rd.ShiftA) and $FF;
        R := (V shr Rd.ShiftR) and $FF;
        G := (V shr Rd.ShiftG) and $FF;
        B := (V shr Rd.ShiftB) and $FF;
      end else begin
        C := AImage.Colors[X, Y];
        A := C.Alpha shr 8;
        R := C.Red shr 8;
        G := C.Green shr 8;
        B := C.Blue shr 8;
      end;
      P^ := (A shl 24) or ((R * A div 255) shl 16) or ((G * A div 255) shl 8) or (B * A div 255);
      Inc(P);
    end;
  end;
  FDC := CreateCompatibleDC(0);
  FOldBmp := SelectObject(FDC, FDib);
end;

destructor TCSSWinBitmap.Destroy;
begin
  if FDC <> 0 then begin
    SelectObject(FDC, FOldBmp);
    DeleteDC(FDC);
  end;
  if FDib <> 0 then DeleteObject(FDib);
  inherited Destroy;
end;
{$endif}

function ToByte(AValue: Single): Byte; inline;
begin
  if AValue <= 0 then Result := 0
  else if AValue >= 1 then Result := 255
  else Result := Round(AValue * 255);
end;

function SamplesPerAxis: Integer; inline;
begin
  if CSSAntialiasing then Result := 4 else Result := 1;
end;

(*
  Pattern of dashed or dotted border side. Every side has own path: from middle of start corner (join with
  previous side) through straight part to middle of end corner. Dashes (dots) are at both ends of path,
  so corners are joined and dashes follow rounded corners.
  Local frame of side: X along side (0 = start of side), Y from outer edge inside.
*)
type
  TCSSSidePattern = record
    Style: TCSSBorderStyle;     // cbsDashed, cbsDotted, other = solid
    W, Len: Single;             // border width, side length
    SA, SB, EA, EB: Single;     // radii of start and end corner (along side, cross side)
    SMid, EMid: Single;         // middle radius of corner arcs
    Origin: Single;             // local X of pattern position A0 (start of straight part)
    A0, Total: Single;          // pattern length in start corner, total length of path
    Ls: Single;                 // length of straight part
    Dash, Gap: Single;
    DotCount: Integer;
    DotStep: Single;
  end;
  TCSSSidePatterns = array[TCSSSide] of TCSSSidePattern;

procedure SideLocal(const S: TCSSPaintShape; ASide: TCSSSide; X, Y: Single; out LX, LY: Single); inline;
begin
  case ASide of
    csTop: begin LX := X - S.L; LY := Y - S.T; end;
    csRight: begin LX := Y - S.T; LY := S.R - X; end;
    csBottom: begin LX := S.R - X; LY := S.B - Y; end;
    else begin LX := S.B - Y; LY := X - S.L; end;
  end;
end;

procedure SideToCanvas(const S: TCSSPaintShape; ASide: TCSSSide; LX, LY: Single; out X, Y: Single); inline;
begin
  case ASide of
    csTop: begin X := S.L + LX; Y := S.T + LY; end;
    csRight: begin X := S.R - LY; Y := S.T + LX; end;
    csBottom: begin X := S.R - LX; Y := S.B - LY; end;
    else begin X := S.L + LY; Y := S.B - LX; end;
  end;
end;

function MakeSidePattern(const S: TCSSPaintShape; ASide: TCSSSide; AStyle: TCSSBorderStyle): TCSSSidePattern;
const
  START_CORNER: array[TCSSSide] of Integer = (0, 3, 2, 1);    // top, left, bottom, right
  END_CORNER: array[TCSSSide] of Integer = (1, 0, 3, 2);
  START_ADJ: array[TCSSSide] of TCSSSide = (csLeft, csBottom, csRight, csTop);
  END_ADJ: array[TCSSSide] of TCSSSide = (csRight, csTop, csLeft, csBottom);
var
  P: TCSSSidePattern;
  SC, EC, N: Integer;
  Share, Ls, A1, EOrigin: Single;
begin
  P := Default(TCSSSidePattern);
  P.Style := AStyle;
  P.W := S.BW[ASide];
  if ASide in [csTop, csBottom] then P.Len := S.R - S.L else P.Len := S.B - S.T;
  SC := START_CORNER[ASide];
  EC := END_CORNER[ASide];
  if ASide in [csTop, csBottom] then begin
    P.SA := S.RX[SC]; P.SB := S.RY[SC]; P.EA := S.RX[EC]; P.EB := S.RY[EC];
  end else begin
    P.SA := S.RY[SC]; P.SB := S.RX[SC]; P.EA := S.RY[EC]; P.EB := S.RX[EC];
  end;
  // part of corner arc which belongs to this side (join from outer to inner corner)
  if (P.SA > 0) and (P.SB > 0) then begin
    P.SMid := Max(0.5, (P.SA + P.SB) / 2 - P.W / 2);
    if P.W + S.BW[START_ADJ[ASide]] > 0 then Share := P.W / (P.W + S.BW[START_ADJ[ASide]]) else Share := 1;
    P.A0 := P.SMid * Pi / 2 * Share;
    P.Origin := P.SA;
  end else begin
    P.A0 := 0;
    P.Origin := S.BW[START_ADJ[ASide]] / 2;      // square corner: middle of corner
    if AStyle = cbsDotted then P.Origin := Max(S.BW[START_ADJ[ASide]], P.W) / 2;   // whole dot inside
  end;
  if (P.EA > 0) and (P.EB > 0) then begin
    P.EMid := Max(0.5, (P.EA + P.EB) / 2 - P.W / 2);
    if P.W + S.BW[END_ADJ[ASide]] > 0 then Share := P.W / (P.W + S.BW[END_ADJ[ASide]]) else Share := 1;
    A1 := P.EMid * Pi / 2 * Share;
    EOrigin := P.Len - P.EA;
  end else begin
    A1 := 0;
    EOrigin := P.Len - S.BW[END_ADJ[ASide]] / 2;
    if AStyle = cbsDotted then EOrigin := P.Len - Max(S.BW[END_ADJ[ASide]], P.W) / 2;
  end;
  Ls := Max(0, EOrigin - P.Origin);
  P.Ls := Ls;
  P.Total := P.A0 + Ls + A1;
  if P.W <= 0 then Exit(P);
  if AStyle = cbsDashed then begin
    P.Dash := Max(2, 3 * P.W);
    P.Gap := P.Dash;
    N := Max(1, Round((P.Total + P.Gap) / (P.Dash + P.Gap)));
    while (N > 1) and ((P.Total - N * P.Dash) / (N - 1) < P.W) do Dec(N);
    if N > 1 then P.Gap := (P.Total - N * P.Dash) / (N - 1)
    else if P.Total > 3 * P.W then begin    // short side: shorter dashes at both corners (as browsers)
      P.Gap := Max(P.W, P.Total / 3);
      P.Dash := (P.Total - P.Gap) / 2;
    end else begin
      P.Dash := P.Total;                    // very short side is solid
      P.Gap := -1;
    end;
  end else
  if AStyle = cbsDotted then begin
    P.DotCount := Max(1, Round(P.Total / (2 * P.W)));
    P.DotStep := P.Total / P.DotCount;
  end;
  Result := P;
end;

(*
  Position T on path and distance V from outer edge for point of side
*)
procedure SidePathPos(const S: TCSSPaintShape; ASide: TCSSSide; const P: TCSSSidePattern; X, Y: Single; out T, V: Single);
var
  LX, LY, Phi, Delta: Single;
begin
  SideLocal(S, ASide, X, Y, LX, LY);
  if (P.SA > 0) and (P.SB > 0) and (LX < P.SA) then begin
    Phi := ArcTan2(LY - P.SB, LX - P.SA);
    Delta := EnsureRange(-Pi / 2 - Phi, 0, Pi / 2);
    T := P.A0 - Delta * P.SMid;
    V := (P.SA + P.SB) / 2 - Sqrt(Sqr(LX - P.SA) + Sqr(LY - P.SB));
  end else
  if (P.EA > 0) and (P.EB > 0) and (LX > P.Len - P.EA) then begin
    Phi := ArcTan2(LY - P.EB, LX - (P.Len - P.EA));
    Delta := EnsureRange(Phi + Pi / 2, 0, Pi / 2);
    T := P.Total - (P.Total - P.A0 - (P.Len - P.EA - P.Origin)) + Delta * P.EMid;
    V := (P.EA + P.EB) / 2 - Sqrt(Sqr(LX - (P.Len - P.EA)) + Sqr(LY - P.EB));
  end else begin
    T := P.A0 + LX - P.Origin;
    V := LY;
  end;
end;

function PatternOnAt(const P: TCSSSidePattern; T, V: Single): Boolean;
var
  K: Integer;
  M: Single;
begin
  case P.Style of
    cbsDashed: begin
      T := EnsureRange(T, 0, P.Total);
      if P.Gap < 0 then
        Result := Abs(T - P.Total / 2) <= P.Dash / 2
      else begin
        M := T - Floor(T / (P.Dash + P.Gap)) * (P.Dash + P.Gap);
        Result := (M < P.Dash) or (T >= P.Total - 0.01);
      end;
    end;
    cbsDotted: begin
      K := EnsureRange(Round(T / P.DotStep), 0, P.DotCount);
      Result := Sqr(T - K * P.DotStep) + Sqr(V - P.W / 2) <= Sqr(P.W / 2);
    end;
    else
      Result := True;
  end;
end;

function PatternOn(const S: TCSSPaintShape; ASide: TCSSSide; const P: TCSSSidePattern; X, Y: Single): Boolean;
var
  T, V: Single;
begin
  if not (P.Style in [cbsDashed, cbsDotted]) then Exit(True);
  SidePathPos(S, ASide, P, X, Y, T, V);
  Result := PatternOnAt(P, T, V);
end;

(*
  Center of dot at path position T (canvas coordinates): dots are circles on middle line of border
*)
function DotCenter(const S: TCSSPaintShape; ASide: TCSSSide; const P: TCSSSidePattern; T: Single): TPointF;
var
  LX, LY, Phi: Single;
begin
  if (T < P.A0) and (P.SA > 0) and (P.SB > 0) then begin
    Phi := -Pi / 2 - (P.A0 - T) / P.SMid;
    LX := P.SA + P.SMid * Cos(Phi);
    LY := P.SB + P.SMid * Sin(Phi);
  end else
  if (T > P.A0 + P.Ls) and (P.EA > 0) and (P.EB > 0) then begin
    Phi := -Pi / 2 + (T - P.A0 - P.Ls) / P.EMid;
    LX := P.Len - P.EA + P.EMid * Cos(Phi);
    LY := P.EB + P.EMid * Sin(Phi);
  end else begin
    LX := P.Origin + T - P.A0;
    LY := P.W / 2;
  end;
  SideToCanvas(S, ASide, LX, LY, Result.x, Result.y);
end;

function PatternKey(const P: TCSSSidePattern): String;
begin
  if P.Style in [cbsDashed, cbsDotted] then
    Result := Format('%d:%.2f:%.2f:%.2f', [Ord(P.Style), P.Total, P.A0, P.Origin])
  else
    Result := 's';
end;

(*
  Rasterize part of shape (background and borders) to bitmap with alpha
  AColors: background, top, left, bottom, right (alpha 0 = not painted)
*)
function RasterizeShape(const S: TCSSPaintShape; ACorner: Integer; X0, Y0, AWidth, AHeight: Integer;
  const AColors: array of TCSSRGBA; const APatterns: TCSSSidePatterns): TBitmap;
const
  KIND_TO_SIDE: array[TCSSSampleKind] of TCSSSide = (csTop, csTop, csTop, csLeft, csBottom, csRight);
var
  PX, PY: Single;
  Img: TLazIntfImage;
  X, Y, SX, SY, N: Integer;
  SR, SG, SB, SA, Step: Single;
  Kind: TCSSSampleKind;
  C: TCSSRGBA;
  Wr: TCSSPixelWriter;
begin
  N := SamplesPerAxis;
  Step := 1 / N;
  Img := NewAlphaImage(AWidth, AHeight);
  try
    Wr := PixelWriter(Img);
    for Y := 0 to AHeight - 1 do begin
      WriterLine(Wr, Y);
      for X := 0 to AWidth - 1 do begin
        SR := 0; SG := 0; SB := 0; SA := 0;
        for SY := 0 to N - 1 do
          for SX := 0 to N - 1 do begin
            PX := X0 + X + (SX + 0.5) * Step;
            PY := Y0 + Y + (SY + 0.5) * Step;
            Kind := SampleShape(S, ACorner, PX, PY);
            if Kind = cskOutside then Continue;
            // dashed border: gap shows background, dotted side is background (dots are painted as whole circles later)
            if Kind in [cskTop, cskLeft, cskBottom, cskRight] then
              case APatterns[KIND_TO_SIDE[Kind]].Style of
                cbsDotted: Kind := cskBackground;
                cbsDashed: if not PatternOn(S, KIND_TO_SIDE[Kind], APatterns[KIND_TO_SIDE[Kind]], PX, PY) then Kind := cskBackground;
              end;
            C := AColors[Ord(Kind) - 1];
            if (C.A < 1) and (Kind <> cskBackground) then begin   // transparent border shows background
              SR := SR + AColors[0].R * AColors[0].A * (1 - C.A);
              SG := SG + AColors[0].G * AColors[0].A * (1 - C.A);
              SB := SB + AColors[0].B * AColors[0].A * (1 - C.A);
              SA := SA + AColors[0].A * (1 - C.A);
            end;
            SR := SR + C.R * C.A;
            SG := SG + C.G * C.A;
            SB := SB + C.B * C.A;
            SA := SA + C.A;
          end;
        if SA > 0 then
          WritePixel(Wr, X, ToByte(SR / SA), ToByte(SG / SA), ToByte(SB / SA), ToByte(SA / (N * N)))
        else
          WritePixel(Wr, X, 0, 0, 0, 0);
      end;
    end;
    Result := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
end;

function RGBAFromColor(AColor: TColor; AAlpha: Single = 1): TCSSRGBA;
begin
  AColor := ColorToRGB(AColor);
  Result.R := Red(AColor) / 255;
  Result.G := Green(AColor) / 255;
  Result.B := Blue(AColor) / 255;
  Result.A := AAlpha;
end;

function RGBAKey(const C: TCSSRGBA): String;
begin
  Result := IntToHex(Round(C.R * 255), 2) + IntToHex(Round(C.G * 255), 2) + IntToHex(Round(C.B * 255), 2) + IntToHex(Round(C.A * 255), 2);
end;

(*
  Get cached rasterized corner
*)
function CornerCache: TStringList;
begin
  if CSSCornerCache = nil then begin
    CSSCornerCache := TCSSKeyList.Create;
    CSSCornerCache.Sorted := True;
    CSSCornerCache.CaseSensitive := True;
    CSSCornerCache.OwnsObjects := True;
  end;
  Result := CSSCornerCache;
end;

var
  CSSPaintTransient: Boolean;    // colors of painted node are animated: its bitmaps are used once, not cached
  CSSPaintTemp: TList;           // bitmaps used once (freed after the node is painted)

procedure AddPaintCache(const AKey: String; ABitmap: TBitmap);
begin
  if CSSPaintTransient then begin
    if CSSPaintTemp = nil then CSSPaintTemp := TList.Create;
    CSSPaintTemp.Add(ABitmap);
  end else
    CSSCornerCache.AddObject(AKey, ABitmap);
end;

procedure FreePaintTemp;
var
  I: Integer;
begin
  if CSSPaintTemp = nil then Exit;
  for I := 0 to CSSPaintTemp.Count - 1 do TObject(CSSPaintTemp[I]).Free;
  CSSPaintTemp.Clear;
end;

(*
  Cached 1x1 bitmap with color and alpha, StretchDraw of it fills rectangle with semi-transparent color
*)
function CSSAlphaBitmap(R, G, B, A: Byte): TBitmap;
var
  I: Integer;
  Key: String;
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
begin
  Key := 'A' + IntToHex(R, 2) + IntToHex(G, 2) + IntToHex(B, 2) + IntToHex(A, 2);
  if CornerCache.Find(Key, I) then Exit(TBitmap(CSSCornerCache.Objects[I]));
  Img := NewAlphaImage(1, 1);
  try
    Wr := PixelWriter(Img);
    WriterLine(Wr, 0);
    WritePixel(Wr, 0, R, G, B, A);
    Result := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  AddPaintCache(Key, Result);
end;


function CornerBitmap(const AKey: String; const S: TCSSPaintShape; ACorner: Integer; const ARect: TRect;
  const AColors: array of TCSSRGBA; const APatterns: TCSSSidePatterns): TBitmap;
var
  X: Integer;
begin
  CornerCache;
  if CSSCornerCache.Find(AKey, X) then Exit(TBitmap(CSSCornerCache.Objects[X]));
  if CSSCornerCache.Count > CSS_CORNER_CACHE_LIMIT then CSSCornerCache.Clear;
  Result := RasterizeShape(S, ACorner, ARect.Left, ARect.Top, ARect.Width, ARect.Height, AColors, APatterns);
  AddPaintCache(AKey, Result);
end;

{ svg icons }

(*
  Inline <svg> icons with stroked shapes (like lucide.dev: path, line, polyline, polygon, rect, circle, ellipse).
  Shapes are flattened to line segments, coverage of pixel is computed from distance to nearest segment, so
  lines are antialiased with round caps and joins. Color is currentColor (text color of node). Fills, <g>
  transforms and other svg features are not supported (icons only).
*)
type
  TCSSSvgSeg = record
    X1, Y1, X2, Y2: Single;
  end;
  TCSSSvgSegs = array of TCSSSvgSeg;

procedure SvgParseShapes(const ASvg: String; var ASegs: TCSSSvgSegs);
var
  Count: Integer;
  CX, CY, SX, SY, LX, LY: Single;   // current point, start of subpath, last control point
  S: String;
  P: Integer;

  procedure AddSeg(X1, Y1, X2, Y2: Single);
  begin
    if Count >= Length(ASegs) then SetLength(ASegs, Count * 2 + 16);
    ASegs[Count].X1 := X1; ASegs[Count].Y1 := Y1;
    ASegs[Count].X2 := X2; ASegs[Count].Y2 := Y2;
    Inc(Count);
  end;
  procedure LineTo(X, Y: Single);
  begin
    AddSeg(CX, CY, X, Y);
    CX := X; CY := Y;
  end;
  procedure CubicTo(X1, Y1, X2, Y2, X, Y: Single);
  var
    I: Integer;
    T, U: Single;
  begin
    for I := 1 to 12 do begin
      T := I / 12; U := 1 - T;
      LineTo(U*U*U*CX + 3*U*U*T*X1 + 3*U*T*T*X2 + T*T*T*X, U*U*U*CY + 3*U*U*T*Y1 + 3*U*T*T*Y2 + T*T*T*Y);
    end;
  end;
  procedure QuadTo(X1, Y1, X, Y: Single);
  begin
    CubicTo(CX + 2/3*(X1 - CX), CY + 2/3*(Y1 - CY), X + 2/3*(X1 - X), Y + 2/3*(Y1 - Y), X, Y);
  end;
  // https://www.w3.org/TR/SVG11/implnote.html#ArcConversionEndpointToCenter
  procedure ArcTo(RX, RY, Angle: Single; Large, Sweep: Boolean; X, Y: Single);
  var
    Phi, CP, SP, X1p, Y1p, L, Sq, Cxp, Cyp, MX, MY, T1, DT: Single;
    I, N: Integer;
  begin
    if ((X = CX) and (Y = CY)) then Exit;
    RX := Abs(RX); RY := Abs(RY);
    if (RX = 0) or (RY = 0) then begin
      LineTo(X, Y);
      Exit;
    end;
    Phi := DegToRad(Angle);
    CP := Cos(Phi); SP := Sin(Phi);
    X1p := CP * (CX - X) / 2 + SP * (CY - Y) / 2;
    Y1p := -SP * (CX - X) / 2 + CP * (CY - Y) / 2;
    L := Sqr(X1p) / Sqr(RX) + Sqr(Y1p) / Sqr(RY);
    if L > 1 then begin
      RX := RX * Sqrt(L); RY := RY * Sqrt(L);
    end;
    Sq := (Sqr(RX) * Sqr(RY) - Sqr(RX) * Sqr(Y1p) - Sqr(RY) * Sqr(X1p)) / (Sqr(RX) * Sqr(Y1p) + Sqr(RY) * Sqr(X1p));
    Sq := Sqrt(Max(0, Sq));
    if Large = Sweep then Sq := -Sq;
    Cxp := Sq * RX * Y1p / RY;
    Cyp := -Sq * RY * X1p / RX;
    MX := CP * Cxp - SP * Cyp + (CX + X) / 2;
    MY := SP * Cxp + CP * Cyp + (CY + Y) / 2;
    T1 := ArcTan2((Y1p - Cyp) / RY, (X1p - Cxp) / RX);
    DT := ArcTan2((-Y1p - Cyp) / RY, (-X1p - Cxp) / RX) - T1;
    if Sweep and (DT < 0) then DT := DT + 2 * Pi
    else if not Sweep and (DT > 0) then DT := DT - 2 * Pi;
    N := Max(2, Ceil(Abs(DT) / (Pi / 16)));
    for I := 1 to N - 1 do
      LineTo(MX + RX * Cos(T1 + DT * I / N) * CP - RY * Sin(T1 + DT * I / N) * SP,
        MY + RX * Cos(T1 + DT * I / N) * SP + RY * Sin(T1 + DT * I / N) * CP);
    LineTo(X, Y);
  end;
  procedure Ellipse(X, Y, RX, RY: Single);
  begin
    CX := X + RX; CY := Y;
    ArcTo(RX, RY, 0, False, True, X - RX, Y);
    ArcTo(RX, RY, 0, False, True, X + RX, Y);
  end;

  // tokens of path data and points: numbers (also "1.5.5", "-1-2", "1e-3") and single char flags
  function More: Boolean;
  begin
    while (P <= Length(S)) and (S[P] in [' ', ',', #9, #10, #13]) do Inc(P);
    Result := (P <= Length(S)) and (S[P] in ['0'..'9', '.', '-', '+']);
  end;
  function Num: Single;
  var
    St: Integer;
    Dot: Boolean;
  begin
    Result := 0;
    if not More then Exit;
    St := P;
    if S[P] in ['-', '+'] then Inc(P);
    Dot := False;
    while (P <= Length(S)) and ((S[P] in ['0'..'9']) or ((S[P] = '.') and not Dot)) do begin
      if S[P] = '.' then Dot := True;
      Inc(P);
    end;
    if (P <= Length(S)) and (S[P] in ['e', 'E']) then begin
      Inc(P);
      if (P <= Length(S)) and (S[P] in ['-', '+']) then Inc(P);
      while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
    end;
    Result := CSSStrToFloatDef(Copy(S, St, P - St), 0);
  end;
  function Flag: Boolean;
  begin
    Result := False;
    if not More then Exit;
    Result := S[P] = '1';
    Inc(P);
  end;

  procedure ParsePath(const AData: String);
  var
    Cmd: Char;
    Rel: Boolean;
    DX, DY, X1, Y1, X2, Y2, X, Y, RX, RY, A: Single;
    Large, Sweep: Boolean;
  begin
    S := AData;
    P := 1;
    CX := 0; CY := 0; SX := 0; SY := 0; LX := 0; LY := 0;
    Cmd := ' ';
    while P <= Length(S) do begin
      while (P <= Length(S)) and (S[P] in [' ', ',', #9, #10, #13]) do Inc(P);
      if P > Length(S) then Break;
      if S[P] in ['A'..'Z', 'a'..'z'] then begin
        Cmd := S[P];
        Inc(P);
      end else if not More then begin
        Inc(P);        // unknown char
        Continue;
      end;
      Rel := Cmd in ['a'..'z'];
      if Rel then begin DX := CX; DY := CY; end else begin DX := 0; DY := 0; end;
      case UpCase(Cmd) of
        'M': begin
          CX := Num + DX; CY := Num + DY;
          SX := CX; SY := CY;
          if Rel then Cmd := 'l' else Cmd := 'L';   // next pairs are lines
        end;
        'L': begin
          X := Num + DX; Y := Num + DY;      // arguments are read in order (evaluation order of parameters is not defined)
          LineTo(X, Y);
        end;
        'H': LineTo(Num + DX, CY);
        'V': LineTo(CX, Num + DY);
        'C': begin
          X1 := Num + DX; Y1 := Num + DY; X2 := Num + DX; Y2 := Num + DY; X := Num + DX; Y := Num + DY;
          CubicTo(X1, Y1, X2, Y2, X, Y);
          LX := X2; LY := Y2;
          Continue;
        end;
        'S': begin
          if UpCase(Cmd) = 'S' then begin X1 := 2 * CX - LX; Y1 := 2 * CY - LY; end;
          X2 := Num + DX; Y2 := Num + DY; X := Num + DX; Y := Num + DY;
          CubicTo(X1, Y1, X2, Y2, X, Y);
          LX := X2; LY := Y2;
          Continue;
        end;
        'Q': begin
          X1 := Num + DX; Y1 := Num + DY; X := Num + DX; Y := Num + DY;
          QuadTo(X1, Y1, X, Y);
          LX := X1; LY := Y1;
          Continue;
        end;
        'T': begin
          X1 := 2 * CX - LX; Y1 := 2 * CY - LY; X := Num + DX; Y := Num + DY;
          QuadTo(X1, Y1, X, Y);
          LX := X1; LY := Y1;
          Continue;
        end;
        'A': begin
          RX := Num; RY := Num; A := Num;
          Large := Flag; Sweep := Flag; X := Num + DX; Y := Num + DY;
          ArcTo(RX, RY, A, Large, Sweep, X, Y);
        end;
        'Z': begin
          LineTo(SX, SY);
          Cmd := ' ';
        end;
        else Inc(P);
      end;
      LX := CX; LY := CY;     // reflected control point is current point after other commands
    end;
  end;

  function Attr(const ATag, AName: String): String;
  var
    I, J: Integer;
  begin
    Result := '';
    I := Pos(' ' + AName + '="', ATag);
    if I = 0 then Exit;
    I := I + Length(AName) + 3;
    J := I;
    while (J <= Length(ATag)) and (ATag[J] <> '"') do Inc(J);
    Result := Copy(ATag, I, J - I);
  end;
  function AttrF(const ATag, AName: String): Single;
  begin
    Result := CSSStrToFloatDef(Attr(ATag, AName), 0);
  end;
  procedure Points(const AData: String; AClose: Boolean);
  var
    X, Y, X0, Y0: Single;
    First: Boolean;
  begin
    S := AData;
    P := 1;
    First := True;
    X0 := 0; Y0 := 0;
    while More do begin
      X := Num; Y := Num;
      if First then begin
        CX := X; CY := Y; X0 := X; Y0 := Y;
        First := False;
      end else
        LineTo(X, Y);
    end;
    if AClose and not First then LineTo(X0, Y0);
  end;
  procedure RoundRect(X, Y, W, H, RX, RY: Single);
  begin
    if (RX <= 0) and (RY > 0) then RX := RY;
    if (RY <= 0) and (RX > 0) then RY := RX;
    RX := Min(RX, W / 2); RY := Min(RY, H / 2);
    CX := X + RX; CY := Y;
    LineTo(X + W - RX, Y);
    ArcTo(RX, RY, 0, False, True, X + W, Y + RY);
    LineTo(X + W, Y + H - RY);
    ArcTo(RX, RY, 0, False, True, X + W - RX, Y + H);
    LineTo(X + RX, Y + H);
    ArcTo(RX, RY, 0, False, True, X, Y + H - RY);
    LineTo(X, Y + RY);
    ArcTo(RX, RY, 0, False, True, X + RX, Y);
  end;

var
  Src, Tag, Name: String;
  I, J: Integer;
begin
  Count := 0;
  ASegs := nil;
  Src := StringReplace(StringReplace(StringReplace(ASvg, #9, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]), #13, ' ', [rfReplaceAll]);
  I := Pos('<', Src);
  while I > 0 do begin
    J := I;
    while (J <= Length(Src)) and (Src[J] <> '>') do Inc(J);
    Tag := Copy(Src, I, J - I + 1);
    Name := LowerCase(Copy(Tag, 2, Max(0, Pos(' ', Tag) - 2)));
    if Name = 'path' then ParsePath(Attr(Tag, 'd'))
    else if Name = 'line' then begin
      CX := AttrF(Tag, 'x1'); CY := AttrF(Tag, 'y1');
      LineTo(AttrF(Tag, 'x2'), AttrF(Tag, 'y2'));
    end
    else if Name = 'polyline' then Points(Attr(Tag, 'points'), False)
    else if Name = 'polygon' then Points(Attr(Tag, 'points'), True)
    else if Name = 'rect' then
      RoundRect(AttrF(Tag, 'x'), AttrF(Tag, 'y'), AttrF(Tag, 'width'), AttrF(Tag, 'height'), AttrF(Tag, 'rx'), AttrF(Tag, 'ry'))
    else if Name = 'circle' then Ellipse(AttrF(Tag, 'cx'), AttrF(Tag, 'cy'), AttrF(Tag, 'r'), AttrF(Tag, 'r'))
    else if Name = 'ellipse' then Ellipse(AttrF(Tag, 'cx'), AttrF(Tag, 'cy'), AttrF(Tag, 'rx'), AttrF(Tag, 'ry'));
    I := Pos('<', Src, J);
  end;
  SetLength(ASegs, Count);
end;

(*
  Bitmap of icon (cached): AW x AH pixels, viewBox is scaled to fit and centered, alpha = coverage of stroke
*)
function SvgIconBitmap(const ASvg, AViewBox: String; AStroke: Single; AW, AH: Integer; AColor: TColor; AAlpha: Byte): TBitmap;
var
  Key: String;
  X, Y, I, Idx: Integer;
  Segs: TCSSSvgSegs;
  VB: TStringArray;
  VX, VY, VW, VH, K, OX, OY, Half, PX, PY, DX, DY, LenSq, T, D, DMin, MinX, MaxX, MinY, MaxY, Cov: Single;
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
  RGB: LongInt;
begin
  RGB := ColorToRGB(AColor);
  Key := Format('V%d,%d,%x,%d,%g,%s|', [AW, AH, RGB, AAlpha, AStroke, AViewBox]) + ASvg;
  CornerCache;
  if CSSCornerCache.Find(Key, Idx) then Exit(TBitmap(CSSCornerCache.Objects[Idx]));
  if CSSCornerCache.Count > CSS_CORNER_CACHE_LIMIT then CSSCornerCache.Clear;
  VX := 0; VY := 0; VW := 24; VH := 24;
  VB := StringReplace(Trim(AViewBox), ',', ' ', [rfReplaceAll]).Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(VB) = 4 then begin
    VX := CSSStrToFloatDef(VB[0], 0); VY := CSSStrToFloatDef(VB[1], 0);
    VW := CSSStrToFloatDef(VB[2], 24); VH := CSSStrToFloatDef(VB[3], 24);
  end;
  if (VW <= 0) or (VH <= 0) then begin VW := 24; VH := 24; end;
  K := Min(AW / VW, AH / VH);
  OX := (AW - VW * K) / 2 - VX * K;
  OY := (AH - VH * K) / 2 - VY * K;
  SvgParseShapes(ASvg, Segs);
  if Segs = nil then Exit(nil);     // fully transparent bitmap is painted black on Windows
  for I := 0 to High(Segs) do
    with Segs[I] do begin
      X1 := X1 * K + OX; Y1 := Y1 * K + OY;
      X2 := X2 * K + OX; Y2 := Y2 * K + OY;
    end;
  Half := Max(0.5, AStroke * K / 2);
  Img := NewAlphaImage(Max(1, AW), Max(1, AH));
  try
    Wr := PixelWriter(Img);
    for Y := 0 to AH - 1 do begin
      WriterLine(Wr, Y);
      PY := Y + 0.5;
      for X := 0 to AW - 1 do begin
        PX := X + 0.5;
        DMin := MaxSingle;
        for I := 0 to High(Segs) do
          with Segs[I] do begin
            if X1 < X2 then begin MinX := X1; MaxX := X2; end else begin MinX := X2; MaxX := X1; end;
            if Y1 < Y2 then begin MinY := Y1; MaxY := Y2; end else begin MinY := Y2; MaxY := Y1; end;
            if (PX < MinX - Half - 1) or (PX > MaxX + Half + 1) or (PY < MinY - Half - 1) or (PY > MaxY + Half + 1) then Continue;
            DX := X2 - X1; DY := Y2 - Y1;
            LenSq := DX * DX + DY * DY;
            if LenSq > 0 then T := EnsureRange(((PX - X1) * DX + (PY - Y1) * DY) / LenSq, 0, 1) else T := 0;
            D := Sqr(PX - X1 - T * DX) + Sqr(PY - Y1 - T * DY);
            if D < DMin then DMin := D;
          end;
        if DMin < MaxSingle then Cov := EnsureRange(Half - Sqrt(DMin) + 0.5, 0, 1) else Cov := 0;
        WritePixel(Wr, X, Red(RGB), Green(RGB), Blue(RGB), Round(Cov * AAlpha));
      end;
    end;
    Result := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  AddPaintCache(Key, Result);
end;

(*
  <svg> node: icon in content box, markup of shapes is in data-svg attribute (see CSSParseHTML)
*)
procedure PaintSvgIcon(ACanvas: TCanvas; ANode: THtmlNode);
var
  R: TRect;
  Sc: Single;
  Bmp: TBitmap;
  Stroke: String;
begin
  R := ANode.FCompSize.ContentRect;
  if (R.Width <= 0) or (R.Height <= 0) or (ANode.GetAttribute('data-svg') = '') then Exit;
  Sc := ANode.RootNode.FPaintScale;
  if Sc <= 0 then Sc := 1;
  Stroke := ANode.GetAttribute('stroke-width');
  if Stroke = '' then Stroke := '2';
  Bmp := SvgIconBitmap(ANode.GetAttribute('data-svg'), ANode.GetAttribute('viewbox'), CSSStrToFloatDef(Stroke, 2),
    Round(R.Width * Sc), Round(R.Height * Sc), ANode.FCompStyle.Color.Value, ANode.FCompStyle.Color.Alpha);
  if Bmp = nil then Exit;
  DrawCachedBitmap(ACanvas, R, Bmp);
end;


procedure CSSClearPaintCache;
begin
  if Assigned(CSSCornerCache) then CSSCornerCache.Clear;
  if Assigned(CSSShadowCache) then CSSShadowCache.Clear;
  if Assigned(CSSImageCache) then CSSImageCache.Clear;
end;

{ background images }

(*
  Register image for url(AName) in background-image (eg. image from resources)
*)
procedure CSSRegisterImage(const AName: String; AGraphic: TGraphic);
var
  X, Y: Integer;
  Bmp: TBitmap;
  Img: TLazIntfImage;
  Data: TCSSImageData;
  C: TFPColor;
begin
  if CSSImageCache = nil then begin
    CSSImageCache := TStringList.Create;
    CSSImageCache.Sorted := True;
    CSSImageCache.OwnsObjects := True;
  end;
  if CSSImageCache.Find(AName, X) then CSSImageCache.Delete(X);
  if AGraphic = nil then Exit;
  if AGraphic is TRasterImage then
    Img := TRasterImage(AGraphic).CreateIntfImage
  else begin
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(AGraphic.Width, AGraphic.Height);
      Bmp.Canvas.Draw(0, 0, AGraphic);
      Img := Bmp.CreateIntfImage;
    finally
      Bmp.Free;
    end;
  end;
  // decode to BGRA array once (fast access in BackgroundLayer)
  Data := TCSSImageData.Create;
  try
    Data.Width := Img.Width;
    Data.Height := Img.Height;
    SetLength(Data.Pixels, Data.Width * Data.Height);
    SetLength(Data.Premultiplied, Data.Width * Data.Height);
    for Y := 0 to Data.Height - 1 do
      for X := 0 to Data.Width - 1 do begin
        C := Img.Colors[X, Y];
        with Data.Pixels[Y * Data.Width + X] do begin
          R := C.Red shr 8; G := C.Green shr 8; B := C.Blue shr 8; A := C.Alpha shr 8;
          if A < 255 then Data.HasAlpha := True;
          Data.Premultiplied[Y * Data.Width + X] := (LongWord(A) shl 24) or (LongWord(R * A div 255) shl 16) or
            (LongWord(G * A div 255) shl 8) or LongWord(B * A div 255);
        end;
      end;
  finally
    Img.Free;
  end;
  CSSImageCache.AddObject(AName, Data);
end;

(*
  Load image for background-image: registered name, absolute path or path relative to application
*)
function CSSLoadImage(const AName: String): TCSSImageData;
var
  X: Integer;
  Pic: TPicture;
  FileName: String;
begin
  Result := nil;
  if AName = '' then Exit;
  if Assigned(CSSImageCache) and CSSImageCache.Find(AName, X) then Exit(TCSSImageData(CSSImageCache.Objects[X]));
  FileName := AName;
  {$ifdef fpc}
  if not FileExists(FileName) then FileName := Application.Location + AName;
  {$endif}
  if not FileExists(FileName) then Exit;
  Pic := TPicture.Create;
  try
    try
      Pic.LoadFromFile(FileName);
      CSSRegisterImage(AName, Pic.Graphic);
    except
      Exit;   // not supported image
    end;
  finally
    Pic.Free;
  end;
  if CSSImageCache.Find(AName, X) then Result := TCSSImageData(CSSImageCache.Objects[X]);
end;

{ gradients }


function CSSColorToRGBA(const AColor: TCSSColor): TCSSRGBA;
begin
  if AColor.ColorType = cctNormal then
    Result := RGBAFromColor(AColor.Value, AColor.Alpha / 255)
  else
    Result := RGBAFromColor(0, 0);
end;

(*
  Parse linear-gradient(...) https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient
*)
function ParseLinearGradient(const AValue: String; AWidth, AHeight: Integer; out AGradient: TCSSGradient): Boolean;
var
  Args, Parts: TStringArray;
  I, First, J, K: Integer;
  S, Dir: String;
  Angle, F: Single;
  C: TCSSColor;
  L: TCSSLength;
  Len: Single;
begin
  Result := False;
  AGradient.Stops := nil;
  S := Trim(AValue);
  if not SameText(Copy(S, 1, 16), 'linear-gradient(') or (S[Length(S)] <> ')') then Exit;
  Args := SplitParameters(Copy(S, 17, Length(S) - 17), ',');
  if Length(Args) = 0 then Exit;
  // direction
  Angle := Pi;   // to bottom
  First := 0;
  Dir := LowerCase(Trim(Args[0]));
  AGradient.DirX := 0;
  AGradient.DirY := 1;
  if Dir.StartsWith('to ') then begin
    First := 1;
    Dir := Trim(Copy(Dir, 4, MaxInt));
    AGradient.DirX := 0; AGradient.DirY := 0;
    // corners: 50% line goes through other two corners
    if Pos('top', Dir) > 0 then AGradient.DirY := -1;
    if Pos('bottom', Dir) > 0 then AGradient.DirY := 1;
    if Pos('left', Dir) > 0 then AGradient.DirX := -1;
    if Pos('right', Dir) > 0 then AGradient.DirX := 1;
    if (AGradient.DirX <> 0) and (AGradient.DirY <> 0) then begin
      AGradient.DirX := AGradient.DirX * AHeight;
      AGradient.DirY := AGradient.DirY * AWidth;
    end;
  end else
  if Dir.EndsWith('deg') or Dir.EndsWith('turn') or Dir.EndsWith('rad') then begin
    First := 1;
    if Dir.EndsWith('deg') then Angle := CSSStrToFloatDef(Copy(Dir, 1, Length(Dir) - 3), 180) * CSS_DEG_RAD
    else if Dir.EndsWith('turn') then Angle := CSSStrToFloatDef(Copy(Dir, 1, Length(Dir) - 4), 0.5) * 2 * Pi
    else Angle := CSSStrToFloatDef(Copy(Dir, 1, Length(Dir) - 3), Pi);
    AGradient.DirX := Sin(Angle);
    AGradient.DirY := -Cos(Angle);
  end;
  F := Sqrt(Sqr(AGradient.DirX) + Sqr(AGradient.DirY));
  if F = 0 then Exit;
  AGradient.DirX := AGradient.DirX / F;
  AGradient.DirY := AGradient.DirY / F;
  Len := Abs(AWidth * AGradient.DirX) + Abs(AHeight * AGradient.DirY);
  // color stops
  for I := First to High(Args) do begin
    Parts := SplitParameters(Trim(Args[I]));
    if Length(Parts) = 0 then Continue;    // empty stop (eg. unset variable)
    C := CSSToColor(Parts[0]);
    if C.ColorType = cctTransparent then begin
      C.ColorType := cctNormal;
      C.Alpha := 0;
    end;
    if C.ColorType <> cctNormal then Continue;
    for J := 0 to Max(0, High(Parts) - 1) do begin      // "color pos1 pos2" creates two stops
      SetLength(AGradient.Stops, Length(AGradient.Stops) + 1);
      K := High(AGradient.Stops);
      AGradient.Stops[K].Color := CSSColorToRGBA(C);
      AGradient.Stops[K].Pos := -1;
      if (Length(Parts) > J + 1) and TryCSSToLengthValue(Parts[J + 1], L) then begin
        if L.LengthType = cltPercentage then AGradient.Stops[K].Pos := L.Value / 100
        else if (L.LengthType = cltPx) and (Len > 0) then AGradient.Stops[K].Pos := L.Value / Len;
      end;
    end;
  end;
  if Length(AGradient.Stops) = 0 then Exit;
  // missing positions: first 0, last 1, others evenly distributed, positions are not decreasing
  if AGradient.Stops[0].Pos < 0 then AGradient.Stops[0].Pos := 0;
  if AGradient.Stops[High(AGradient.Stops)].Pos < 0 then AGradient.Stops[High(AGradient.Stops)].Pos := 1;
  I := 1;
  while I < High(AGradient.Stops) do begin
    if AGradient.Stops[I].Pos < 0 then begin
      J := I;
      while AGradient.Stops[J].Pos < 0 do Inc(J);
      for K := I to J - 1 do
        AGradient.Stops[K].Pos := AGradient.Stops[I - 1].Pos + (AGradient.Stops[J].Pos - AGradient.Stops[I - 1].Pos) * (K - I + 1) / (J - I + 1);
      I := J;
    end;
    Inc(I);
  end;
  for I := 1 to High(AGradient.Stops) do
    AGradient.Stops[I].Pos := Max(AGradient.Stops[I].Pos, AGradient.Stops[I - 1].Pos);
  Result := True;
end;

function GradientColorAt(const AGradient: TCSSGradient; T: Single): TCSSRGBA;
var
  I: Integer;
  F, A1, A2: Single;
  C1, C2: TCSSRGBA;
begin
  with AGradient do begin
    if T <= Stops[0].Pos then Exit(Stops[0].Color);
    if T >= Stops[High(Stops)].Pos then Exit(Stops[High(Stops)].Color);
    I := 1;
    while (I < High(Stops)) and (Stops[I].Pos < T) do Inc(I);
    C1 := Stops[I - 1].Color;
    C2 := Stops[I].Color;
    if Stops[I].Pos > Stops[I - 1].Pos then F := (T - Stops[I - 1].Pos) / (Stops[I].Pos - Stops[I - 1].Pos) else F := 1;
  end;
  // interpolation in premultiplied space
  A1 := C1.A * (1 - F);
  A2 := C2.A * F;
  Result.A := A1 + A2;
  if Result.A > 0 then begin
    Result.R := (C1.R * A1 + C2.R * A2) / Result.A;
    Result.G := (C1.G * A1 + C2.G * A2) / Result.A;
    Result.B := (C1.B * A1 + C2.B * A2) / Result.A;
  end else begin
    Result.R := 0; Result.G := 0; Result.B := 0;
  end;
end;

(*
  Source over: AColor over ADest
*)
function BlendOver(const ADest, AColor: TCSSRGBA): TCSSRGBA;
var
  A: Single;
begin
  A := AColor.A + ADest.A * (1 - AColor.A);
  Result.A := A;
  if A > 0 then begin
    Result.R := (AColor.R * AColor.A + ADest.R * ADest.A * (1 - AColor.A)) / A;
    Result.G := (AColor.G * AColor.A + ADest.G * ADest.A * (1 - AColor.A)) / A;
    Result.B := (AColor.B * AColor.A + ADest.B * ADest.A * (1 - AColor.A)) / A;
  end else begin
    Result.R := 0; Result.G := 0; Result.B := 0;
  end;
end;


(*
  Replace var(--name, fallback) with custom property value of node or its parents
*)
function THtmlNode.ResolveVars(const AValue: String; ADepth: Integer = 0): String;
var
  P, I, Level, Comma: Integer;
  Inner, Name, Fallback, Value: String;
  N: THtmlNode;
  Found: Boolean;
begin
  Result := AValue;
  if ADepth > 8 then Exit;      // recursion limit
  P := Pos('var(', Result);
  while P > 0 do begin
    // find matching parenthesis
    Level := 0;
    Comma := 0;
    I := P + 3;
    repeat
      if Result[I] = '(' then Inc(Level)
      else if Result[I] = ')' then Dec(Level)
      else if (Result[I] = ',') and (Level = 1) and (Comma = 0) then Comma := I;
      Inc(I);
    until (Level = 0) or (I > Length(Result));
    if Level <> 0 then Exit;
    Inner := Copy(Result, P + 4, I - P - 5);
    if Comma > 0 then begin
      Name := Trim(Copy(Result, P + 4, Comma - P - 4));
      Fallback := Trim(Copy(Result, Comma + 1, I - Comma - 2));
    end else begin
      Name := Trim(Inner);
      Fallback := '';
    end;
    Found := False;
    Value := '';
    N := Self;
    while Assigned(N) and not Found do begin
      if Assigned(N.FCompStyle.CustomProps) and (N.FCompStyle.CustomProps.IndexOfName(Name) >= 0) then begin
        Value := N.FCompStyle.CustomProps.Values[Name];
        Found := True;
      end;
      N := N.ParentNode;
    end;
    if not Found then Value := Fallback;
    Value := ResolveVars(Value, ADepth + 1);
    Result := Copy(Result, 1, P - 1) + Value + Copy(Result, I, MaxInt);
    P := Pos('var(', Result);
  end;
end;

(*
  Color with alpha is blended with background of node or nearest parent (borders and text are painted
  without alpha channel)
*)
function THtmlNode.EffectiveColor(const AColor: TCSSColor): TColor;
var
  N: THtmlNode;
  Back: TColor;
  A: Single;
begin
  Result := AColor.Value;
  if AColor.Alpha >= 255 then Exit;
  Back := clWhite;
  N := Self;
  while Assigned(N) do begin
    if (N.FCompStyle.Background.Color.ColorType = cctNormal) and (N.FCompStyle.Background.Color.Alpha = 255) then begin
      Back := N.FCompStyle.Background.Color.Value;
      Break;
    end;
    N := N.ParentNode;
  end;
  A := AColor.Alpha / 255;
  Back := ColorToRGB(Back);
  Result := ColorToRGB(AColor.Value);
  Result := RGBToColor(Round(Red(Result) * A + Red(Back) * (1 - A)), Round(Green(Result) * A + Green(Back) * (1 - A)),
    Round(Blue(Result) * A + Blue(Back) * (1 - A)));
end;

(*
  Destination rectangle of background image (background-size, background-position)
*)
procedure THtmlNode.BackgroundImageRect(AImage: TCSSImageData; AWidth, AHeight: Integer; out ARect: TRectF);
var
  Parts: TStringArray;
  IW, IH, W, H, Scale: Single;
  L: TCSSLength;
  S: String;
  function PosValue(const AValue: String; AFree: Single; out AResult: Single): Boolean;
  begin
    Result := True;
    if (AValue = 'left') or (AValue = 'top') then AResult := 0
    else if AValue = 'center' then AResult := AFree / 2
    else if (AValue = 'right') or (AValue = 'bottom') then AResult := AFree
    else if TryCSSToLengthValue(AValue, L) then begin
      if L.LengthType = cltPercentage then AResult := AFree * L.Value / 100
      else AResult := CalcLength(L, Round(AFree));
    end else
      Result := False;
  end;
var
  X, Y: Single;
begin
  IW := AImage.Width * RootNode.FPixelRatio;
  IH := AImage.Height * RootNode.FPixelRatio;
  W := IW;
  H := IH;
  S := LowerCase(Trim(FCompStyle.Background.Size));
  if (S = 'cover') or (S = 'contain') then begin
    if S = 'cover' then Scale := Max(AWidth / IW, AHeight / IH) else Scale := Min(AWidth / IW, AHeight / IH);
    W := IW * Scale;
    H := IH * Scale;
  end else
  if (S <> '') and (S <> 'auto') then begin
    Parts := SplitParameters(S);
    if (Length(Parts) > 0) and TryCSSToLengthValue(Parts[0], L) and (L.LengthType <> cltAuto) then
      W := CalcLength(L, AWidth);
    if (Length(Parts) > 1) and TryCSSToLengthValue(Parts[1], L) and (L.LengthType <> cltAuto) then
      H := CalcLength(L, AHeight)
    else
      H := IH * W / IW;     // keep aspect ratio
    if (Length(Parts) > 1) and (Parts[0] = 'auto') then W := IW * H / IH;
  end;
  W := Max(1, W);
  H := Max(1, H);
  X := 0;
  Y := 0;
  Parts := SplitParameters(LowerCase(Trim(FCompStyle.Background.Position)));
  if Length(Parts) = 1 then begin
    if (Parts[0] = 'top') or (Parts[0] = 'bottom') then begin
      PosValue('center', AWidth - W, X);
      PosValue(Parts[0], AHeight - H, Y);
    end else begin
      PosValue(Parts[0], AWidth - W, X);
      PosValue('center', AHeight - H, Y);
    end;
  end else
  if Length(Parts) >= 2 then begin
    if (Parts[0] = 'top') or (Parts[0] = 'bottom') then begin   // "top left"
      PosValue(Parts[1], AWidth - W, X);
      PosValue(Parts[0], AHeight - H, Y);
    end else begin
      PosValue(Parts[0], AWidth - W, X);
      PosValue(Parts[1], AHeight - H, Y);
    end;
  end;
  ARect := RectF(X, Y, X + W, Y + H);
end;

(*
  Background with gradient, image or color with alpha is rendered to one bitmap (with rounded corners)
*)
(*
  Background with gradient, image or color with alpha rendered by software (with rounded corners)
  AWidth, AHeight, S, ACornerW, ACornerH are in device pixels (scaled by AScale)
  ARegion - part of background to render (whole background or one corner), cached in ASlot
  Colors are computed as premultiplied integers 0..255
*)
function THtmlNode.BackgroundLayer(const S: TCSSPaintShape; AWidth, AHeight: Integer; const AImage: String;
  const ACornerW, ACornerH: array of Integer; AScale: Single; ASlot: Integer; const ARegion: TRect): TBitmap;
const
  LUT_SIZE = 1024;
var
  Key, Url: String;
  Img: TLazIntfImage;
  Src: TCSSImageData;
  Grad: TCSSGradient;
  HasGrad, Repeating, CornerRow: Boolean;
  X, Y, SX, SY, N, I, Idx, Cov: Integer;
  T, TStep, GradLen, Step: Single;
  Dst: TRectF;
  Local: TCSSPaintShape;
  Wr: TCSSPixelWriter;
  Lut: array of LongWord;               // premultiplied ARGB
  BaseC: TCSSRGBA;
  BA, BR, BG, BB: Integer;              // premultiplied base color
  PA, PR, PG, PB: Integer;              // premultiplied pixel
  // image mapping is separable: source column depends only on X, row only on Y
  ColX0, ColX1, RowY0, RowY1, ColF, RowF: array of Integer;   // fractions 0..256
  ColIn, RowIn: array of Boolean;
  Row0, Row1: PLongWord;
  P00, P10, P01, P11: LongWord;
  FX, FY, W00, W10, W01, W11: Integer;
  procedure MapAxis(ACount: Integer; AStart, ASize: Single; ASrcSize: Integer; var I0, I1, Frac: array of Integer;
    var Inside: array of Boolean);
  var
    K: Integer;
    U: Single;
  begin
    for K := 0 to ACount - 1 do begin
      U := (K + 0.5 - AStart) / ASize;
      if Repeating then U := U - Floor(U);
      Inside[K] := (U >= 0) and (U < 1);
      U := U * ASrcSize - 0.5;
      if U < 0 then U := 0;
      I0[K] := Min(Floor(U), ASrcSize - 1);
      I1[K] := Min(I0[K] + 1, ASrcSize - 1);
      Frac[K] := Round((U - Floor(U)) * 256);
    end;
  end;
  function InCorner(X, Y: Integer): Boolean; inline;
  begin
    Result := ((X < ACornerW[0]) and (Y < ACornerH[0])) or ((X >= AWidth - ACornerW[1]) and (Y < ACornerH[1])) or
      ((X >= AWidth - ACornerW[2]) and (Y >= AHeight - ACornerH[2])) or ((X < ACornerW[3]) and (Y >= AHeight - ACornerH[3]));
  end;
  function PremultipliedOf(const C: TCSSRGBA): LongWord;
  var
    A: Integer;
  begin
    A := ToByte(C.A);
    Result := (LongWord(A) shl 24) or (LongWord(Round(C.R * A)) shl 16) or (LongWord(Round(C.G * A)) shl 8) or LongWord(Round(C.B * A));
  end;
  function Channel(P: LongWord; AShift: Byte): Integer; inline;
  begin
    Result := (P shr AShift) and $FF;
  end;
begin
  Key := Format('%d,%d,%s,%s,%s,%s,%s,%d,%d,%f', [AWidth, AHeight, AImage, RGBAKey(CSSColorToRGBA(FCompStyle.Background.Color)),
    FCompStyle.Background.Size, FCompStyle.Background.Position, FCompStyle.Background.RepeatMode, Ord(CSSAntialiasing),
    Round(RootNode.FPixelRatio * 100), AScale]);
  for I := 0 to 3 do Key := Key + Format(',%f,%f', [S.RX[I], S.RY[I]]);
  Key := Key + Format(',%d,%d,%d,%d', [ARegion.Left, ARegion.Top, ARegion.Right, ARegion.Bottom]);
  if Assigned(FBgCache[ASlot].Bmp) and (FBgCache[ASlot].Key = Key) then Exit(FBgCache[ASlot].Bmp);
  FreeAndNil(FBgCache[ASlot].Bmp);
  FBgCache[ASlot].Key := Key;

  Local := S;   // shape relative to layer
  Local.L := 0; Local.T := 0; Local.R := AWidth; Local.B := AHeight;
  BaseC := CSSColorToRGBA(FCompStyle.Background.Color);
  I := PremultipliedOf(BaseC);
  BA := Channel(I, 24); BR := Channel(I, 16); BG := Channel(I, 8); BB := Channel(I, 0);
  HasGrad := ParseLinearGradient(AImage, Round(AWidth / AScale), Round(AHeight / AScale), Grad);
  Src := nil;
  if not HasGrad and SameText(Copy(Trim(AImage), 1, 4), 'url(') then begin
    Url := Trim(StrBetween(Trim(AImage), '(', ')'));
    Url := StringReplace(StringReplace(Url, '"', '', [rfReplaceAll]), '''', '', [rfReplaceAll]);
    Src := CSSLoadImage(Url);
    if Assigned(Src) and ((Src.Width = 0) or (Src.Height = 0)) then Src := nil;
  end;
  Repeating := not SameText(Trim(FCompStyle.Background.RepeatMode), 'no-repeat');
  GradLen := 1;
  TStep := 0;
  if HasGrad then begin
    // gradient colors table, gradient line parameter T is linear in X
    SetLength(Lut, LUT_SIZE + 1);
    for I := 0 to LUT_SIZE do Lut[I] := PremultipliedOf(BlendOver(BaseC, GradientColorAt(Grad, I / LUT_SIZE)));
    GradLen := Abs(AWidth * Grad.DirX) + Abs(AHeight * Grad.DirY);
    TStep := Grad.DirX / GradLen;
  end;
  if Assigned(Src) then begin
    BackgroundImageRect(Src, Round(AWidth / AScale), Round(AHeight / AScale), Dst);
    Dst := RectF(Dst.Left * AScale, Dst.Top * AScale, Dst.Right * AScale, Dst.Bottom * AScale);
    SetLength(ColX0, AWidth); SetLength(ColX1, AWidth); SetLength(ColF, AWidth); SetLength(ColIn, AWidth);
    SetLength(RowY0, AHeight); SetLength(RowY1, AHeight); SetLength(RowF, AHeight); SetLength(RowIn, AHeight);
    MapAxis(AWidth, Dst.Left, Dst.Width, Src.Width, ColX0, ColX1, ColF, ColIn);
    MapAxis(AHeight, Dst.Top, Dst.Height, Src.Height, RowY0, RowY1, RowF, RowIn);
  end;
  N := SamplesPerAxis;
  Step := 1 / N;

  Img := NewAlphaImage(ARegion.Width, ARegion.Height);
  try
    Wr := PixelWriter(Img);
    for Y := ARegion.Top to ARegion.Bottom - 1 do begin
      WriterLine(Wr, Y - ARegion.Top);
      CornerRow := (Y < ACornerH[0]) or (Y < ACornerH[1]) or (Y >= AHeight - ACornerH[2]) or (Y >= AHeight - ACornerH[3]);
      T := ((ARegion.Left + 0.5 - AWidth / 2) * Grad.DirX + (Y + 0.5 - AHeight / 2) * Grad.DirY) / GradLen + 0.5;
      if Assigned(Src) then begin
        Row0 := @Src.Premultiplied[RowY0[Y] * Src.Width];
        Row1 := @Src.Premultiplied[RowY1[Y] * Src.Width];
        FY := RowF[Y];
      end;
      for X := ARegion.Left to ARegion.Right - 1 do begin
        PA := BA; PR := BR; PG := BG; PB := BB;
        if HasGrad then begin
          Idx := Round(T * LUT_SIZE);
          if Idx < 0 then Idx := 0 else if Idx > LUT_SIZE then Idx := LUT_SIZE;
          I := Lut[Idx];
          PA := Channel(I, 24); PR := Channel(I, 16); PG := Channel(I, 8); PB := Channel(I, 0);
          T := T + TStep;
        end else
        if Assigned(Src) and ColIn[X] and RowIn[Y] then begin
          // bilinear sampling (fixed point, premultiplied)
          FX := ColF[X];
          P00 := Row0[ColX0[X]]; P10 := Row0[ColX1[X]];
          P01 := Row1[ColX0[X]]; P11 := Row1[ColX1[X]];
          W00 := (256 - FX) * (256 - FY); W10 := FX * (256 - FY); W01 := (256 - FX) * FY; W11 := FX * FY;
          PA := (Channel(P00, 24) * W00 + Channel(P10, 24) * W10 + Channel(P01, 24) * W01 + Channel(P11, 24) * W11) shr 16;
          PR := (Channel(P00, 16) * W00 + Channel(P10, 16) * W10 + Channel(P01, 16) * W01 + Channel(P11, 16) * W11) shr 16;
          PG := (Channel(P00, 8) * W00 + Channel(P10, 8) * W10 + Channel(P01, 8) * W01 + Channel(P11, 8) * W11) shr 16;
          PB := (Channel(P00, 0) * W00 + Channel(P10, 0) * W10 + Channel(P01, 0) * W01 + Channel(P11, 0) * W11) shr 16;
          if BA > 0 then begin      // image over background color
            PR := PR + BR * (255 - PA) div 255;
            PG := PG + BG * (255 - PA) div 255;
            PB := PB + BB * (255 - PA) div 255;
            PA := PA + BA * (255 - PA) div 255;
          end;
        end;
        // rounded corners
        if CornerRow and (PA > 0) and InCorner(X, Y) then begin
          Cov := 0;
          for SY := 0 to N - 1 do
            for SX := 0 to N - 1 do
              if InOuterShape(Local, X + (SX + 0.5) * Step, Y + (SY + 0.5) * Step) then Inc(Cov);
          PA := PA * Cov div (N * N);
          PR := PR * Cov div (N * N);
          PG := PG * Cov div (N * N);
          PB := PB * Cov div (N * N);
        end;
        if PA <= 0 then
          WritePixel(Wr, X - ARegion.Left, 0, 0, 0, 0)
        else if PA >= 255 then
          WritePixel(Wr, X - ARegion.Left, Min(PR, 255), Min(PG, 255), Min(PB, 255), 255)
        else
          WritePixel(Wr, X - ARegion.Left, Min(PR * 255 div PA, 255), Min(PG * 255 div PA, 255), Min(PB * 255 div PA, 255), PA);
      end;
    end;
    FBgCache[ASlot].Bmp := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  Result := FBgCache[ASlot].Bmp;
end;

(*
  Bitmap of decoded image for native drawing (StretchDraw)
*)
function ImageBitmap(AData: TCSSImageData): TBitmap;
var
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
  X, Y: Integer;
  P: PCSSPixel;
begin
  if Assigned(AData.Bitmap) then Exit(AData.Bitmap);
  Img := NewAlphaImage(AData.Width, AData.Height);
  try
    Wr := PixelWriter(Img);
    for Y := 0 to AData.Height - 1 do begin
      WriterLine(Wr, Y);
      P := @AData.Pixels[Y * AData.Width];
      for X := 0 to AData.Width - 1 do begin
        WritePixel(Wr, X, P^.R, P^.G, P^.B, P^.A);
        Inc(P);
      end;
    end;
    AData.Bitmap := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  Result := AData.Bitmap;
end;

destructor TCSSImageData.Destroy;
begin
  Bitmap.Free;
  inherited Destroy;
end;

(*
  Horizontal or vertical gradient as 1 pixel strip (stretched by StretchDraw), AWidth, AHeight in device pixels
*)
function THtmlNode.GradientStrip(const AGradient: TCSSGradient; AWidth, AHeight: Integer; const AKey: String): TBitmap;
var
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
  Horizontal: Boolean;
  I, Count: Integer;
  T: Single;
  C, Base: TCSSRGBA;
begin
  if Assigned(FBgCache[5].Bmp) and (FBgCache[5].Key = AKey) then Exit(FBgCache[5].Bmp);
  FreeAndNil(FBgCache[5].Bmp);
  FBgCache[5].Key := AKey;
  Horizontal := Abs(AGradient.DirY) < 1E-6;
  if Horizontal then Count := AWidth else Count := AHeight;
  Base := CSSColorToRGBA(FCompStyle.Background.Color);
  if Horizontal then Img := NewAlphaImage(Count, 1) else Img := NewAlphaImage(1, Count);
  try
    Wr := PixelWriter(Img);
    for I := 0 to Count - 1 do begin
      if Horizontal then begin
        T := (I + 0.5 - AWidth / 2) * AGradient.DirX / AWidth + 0.5;
        WriterLine(Wr, 0);
      end else begin
        T := (I + 0.5 - AHeight / 2) * AGradient.DirY / AHeight + 0.5;
        WriterLine(Wr, I);
      end;
      C := BlendOver(Base, GradientColorAt(AGradient, T));
      if Horizontal then WritePixel(Wr, I, ToByte(C.R), ToByte(C.G), ToByte(C.B), ToByte(C.A))
        else WritePixel(Wr, 0, ToByte(C.R), ToByte(C.G), ToByte(C.B), ToByte(C.A));
    end;
    FBgCache[5].Bmp := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  Result := FBgCache[5].Bmp;
end;

{ box-shadow }


type
  { TCSSShadowSlices - shadow template cut to 9 parts: corners are drawn, edges and center are stretched }
  TCSSShadowSlices = class
    Parts: array[0..8] of TBitmap;   // top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right
    LW, RW, TH, BH: Integer;         // size of corner parts in canvas pixels
    Whole: Boolean;                  // Parts[0] is whole shadow (shadow is smaller than template)
    destructor Destroy; override;
  end;

destructor TCSSShadowSlices.Destroy;
var
  I: Integer;
begin
  for I := 0 to 8 do Parts[I].Free;
  inherited Destroy;
end;

(*
  Parse box-shadow: [inset] <offset-x> <offset-y> [<blur> [<spread>]] [<color>], ...
*)
function THtmlNode.ParseShadows(const AValue: String): TCSSShadowArray;
var
  List, Parts: TStringArray;
  I, J, N: Integer;
  L: TCSSLength;
  Lengths: array[0..3] of Integer;
  C: TCSSColor;
  Sh: TCSSShadow;
begin
  Result := nil;
  if (AValue = '') or SameText(AValue, 'none') then Exit;
  List := SplitParameters(AValue, ',');
  for I := 0 to High(List) do begin
    Parts := SplitParameters(Trim(List[I]));
    Sh := Default(TCSSShadow);
    Sh.Color := CSSToColor('rgba(0,0,0,1)');
    Sh.Color.ColorType := cctCurrentColor;
    N := 0;
    for J := 0 to High(Parts) do begin
      if SameText(Parts[J], 'inset') then Sh.Inset := True
      else if (N < 4) and TryCSSToLengthValue(Parts[J], L) and (L.LengthType <> cltAuto) then begin
        Lengths[N] := CalcLength(L, 0);
        Inc(N);
      end else begin
        C := CSSToColor(Parts[J]);
        if C.ColorType <> cctUndefined then Sh.Color := C;
      end;
    end;
    if N < 2 then Continue;
    Sh.X := Lengths[0];
    Sh.Y := Lengths[1];
    if N > 2 then Sh.Blur := Max(0, Lengths[2]);
    if N > 3 then Sh.Spread := Lengths[3];
    if Sh.Color.ColorType = cctCurrentColor then begin
      Sh.Color := FCompStyle.Color;
      Sh.Color.ColorType := cctNormal;
    end;
    if (Sh.Color.ColorType <> cctNormal) or (Sh.Color.Alpha = 0) then Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Sh;
  end;
end;

(*
  Separable box blur of alpha mask (3 passes approximate gaussian blur)
*)
procedure BlurMask(var AMask: array of Single; AWidth, AHeight: Integer; ASigma: Single);
var
  Radius, Pass, X, Y, I, Count, Len, Stride: Integer;
  Sum: Single;
  Line: array of Single;
  procedure BlurLine(AStart, AStride, ALen: Integer);
  var
    K: Integer;
  begin
    for K := 0 to ALen - 1 do Line[K] := AMask[AStart + K * AStride];
    Sum := 0;
    for K := -Radius to Radius do
      if (K >= 0) and (K < ALen) then Sum := Sum + Line[K];
    for K := 0 to ALen - 1 do begin
      AMask[AStart + K * AStride] := Sum / Count;
      if K - Radius >= 0 then Sum := Sum - Line[K - Radius];
      if K + Radius + 1 < ALen then Sum := Sum + Line[K + Radius + 1];
    end;
  end;
begin
  if ASigma < 0.3 then Exit;
  Radius := (Trunc(Sqrt(4 * ASigma * ASigma + 1)) - 1) div 2;
  if Radius < 1 then Radius := 1;
  Count := 2 * Radius + 1;
  SetLength(Line, Max(AWidth, AHeight));
  for Pass := 1 to 3 do begin
    for Y := 0 to AHeight - 1 do BlurLine(Y * AWidth, 1, AWidth);
    for X := 0 to AWidth - 1 do BlurLine(X, AWidth, AHeight);
  end;
end;

(*
  Render shadow of rounded rectangle and cut it to 9 parts
  AWidth, AHeight - shadow shape size (canvas px), radii in canvas px, AExtent - blur extent
*)
function BuildShadowSlices(AWidth, AHeight: Integer; const ARadius: array of TPoint; ABlur: Integer;
  const AColor: TCSSRGBA; AScale: Single): TCSSShadowSlices;
var
  RL, RR, RT, RB, E, SW, SH, DW, DH, X, Y, SX, SY, N, I: Integer;
  Mask: array of Single;
  RX, RY: array[0..3] of Single;
  Cov, Step: Single;
  XS, YS: array[0..3] of Integer;    // device x/y boundaries of slices: 0, left, right, end
  function Part(AX0, AY0, AX1, AY1: Integer): TBitmap;
  var
    Img: TLazIntfImage;
    Wr: TCSSPixelWriter;
    PX, PY: Integer;
  begin
    Img := NewAlphaImage(Max(1, AX1 - AX0), Max(1, AY1 - AY0));
    try
      Wr := PixelWriter(Img);
      for PY := AY0 to AY0 + Img.Height - 1 do begin
        WriterLine(Wr, PY - AY0);
        for PX := AX0 to AX0 + Img.Width - 1 do
          WritePixel(Wr, PX - AX0, ToByte(AColor.R), ToByte(AColor.G), ToByte(AColor.B),
            ToByte(Mask[EnsureRange(PY, 0, DH - 1) * DW + EnsureRange(PX, 0, DW - 1)] * AColor.A));
      end;
      Result := IntfImageToBitmap(Img);
    finally
      Img.Free;
    end;
  end;
begin
  Result := TCSSShadowSlices.Create;
  RL := Max(ARadius[0].x, ARadius[3].x);
  RR := Max(ARadius[1].x, ARadius[2].x);
  RT := Max(ARadius[0].y, ARadius[1].y);
  RB := Max(ARadius[3].y, ARadius[2].y);
  E := ABlur;
  SW := RL + RR + 2 * E + 1;
  SH := RT + RB + 2 * E + 1;
  Result.Whole := (AWidth < SW) or (AHeight < SH);
  if Result.Whole then begin
    SW := AWidth;
    SH := AHeight;
  end;
  // mask of shape in device pixels
  DW := Max(1, Round((SW + 2 * E) * AScale));
  DH := Max(1, Round((SH + 2 * E) * AScale));
  SetLength(Mask, DW * DH);
  for I := 0 to 3 do begin
    RX[I] := ARadius[I].x * AScale;
    RY[I] := ARadius[I].y * AScale;
  end;
  N := SamplesPerAxis;
  Step := 1 / N;
  for Y := 0 to DH - 1 do
    for X := 0 to DW - 1 do begin
      Cov := 0;
      for SY := 0 to N - 1 do
        for SX := 0 to N - 1 do
          if InRoundRect(E * AScale, E * AScale, (E + SW) * AScale, (E + SH) * AScale, RX, RY,
            X + (SX + 0.5) * Step, Y + (SY + 0.5) * Step) then Cov := Cov + 1;
      Mask[Y * DW + X] := Cov / (N * N);
    end;
  BlurMask(Mask, DW, DH, ABlur * AScale / 2);
  if Result.Whole then begin
    Result.Parts[0] := Part(0, 0, DW, DH);
    Exit;
  end;
  Result.LW := 2 * E + RL;
  Result.RW := RR + 2 * E;
  Result.TH := 2 * E + RT;
  Result.BH := RB + 2 * E;
  XS[0] := 0; XS[1] := Round(Result.LW * AScale); XS[2] := DW - Round(Result.RW * AScale); XS[3] := DW;
  YS[0] := 0; YS[1] := Round(Result.TH * AScale); YS[2] := DH - Round(Result.BH * AScale); YS[3] := DH;
  for Y := 0 to 2 do
    for X := 0 to 2 do
      if (X = 1) or (Y = 1) then   // edges and center: one pixel from middle, stretched when drawn
        Result.Parts[Y * 3 + X] := Part(IfThen(X = 1, XS[1], XS[X]), IfThen(Y = 1, YS[1], YS[Y]),
          IfThen(X = 1, XS[1] + 1, XS[X + 1]), IfThen(Y = 1, YS[1] + 1, YS[Y + 1]))
      else
        Result.Parts[Y * 3 + X] := Part(XS[X], YS[Y], XS[X + 1], YS[Y + 1]);
end;

(*
  Inset shadow (box-shadow: inset ...): inside of padding box, template is cut to 9 parts (center is empty)
  AWidth, AHeight - padding box size, ARadius - inner radii (canvas px)
*)
function InsetMargin(const AShadow: TCSSShadow): Integer;
begin
  Result := 2 * AShadow.Blur + Max(0, AShadow.Spread) + Max(Abs(AShadow.X), Abs(AShadow.Y)) + 1;
end;

function BuildInsetShadowSlices(AWidth, AHeight: Integer; const ARadius: array of TPoint; const AShadow: TCSSShadow;
  const AColor: TCSSRGBA; AScale: Single): TCSSShadowSlices;
var
  RL, RR, RT, RB, M, Ext, SW, SH, DW, DH, X, Y, SX, SY, N, I: Integer;
  Mask, BoxCov: array of Single;
  RX, RY, HX, HY: array[0..3] of Single;
  CH, CB, Step, PX, PY: Single;
  XS, YS: array[0..3] of Integer;
  function Part(AX0, AY0, AX1, AY1: Integer): TBitmap;
  var
    Img: TLazIntfImage;
    Wr: TCSSPixelWriter;
    QX, QY: Integer;
  begin
    Img := NewAlphaImage(Max(1, AX1 - AX0), Max(1, AY1 - AY0));
    try
      Wr := PixelWriter(Img);
      for QY := AY0 to AY0 + Img.Height - 1 do begin
        WriterLine(Wr, QY - AY0);
        for QX := AX0 to AX0 + Img.Width - 1 do
          WritePixel(Wr, QX - AX0, ToByte(AColor.R), ToByte(AColor.G), ToByte(AColor.B),
            ToByte(Mask[EnsureRange(QY, 0, DH - 1) * DW + EnsureRange(QX, 0, DW - 1)] * AColor.A));
      end;
      Result := IntfImageToBitmap(Img);
    finally
      Img.Free;
    end;
  end;
begin
  Result := TCSSShadowSlices.Create;
  RL := Max(ARadius[0].x, ARadius[3].x);
  RR := Max(ARadius[1].x, ARadius[2].x);
  RT := Max(ARadius[0].y, ARadius[1].y);
  RB := Max(ARadius[3].y, ARadius[2].y);
  M := InsetMargin(AShadow);
  SW := RL + RR + 2 * M + 1;
  SH := RT + RB + 2 * M + 1;
  Result.Whole := (AWidth < SW) or (AHeight < SH);
  if Result.Whole then begin
    SW := AWidth;
    SH := AHeight;
  end;
  Ext := 2 * AShadow.Blur + 1;        // outside of padding box (blurred into it)
  DW := Max(1, Round((SW + 2 * Ext) * AScale));
  DH := Max(1, Round((SH + 2 * Ext) * AScale));
  SetLength(Mask, DW * DH);
  SetLength(BoxCov, DW * DH);
  for I := 0 to 3 do begin
    RX[I] := ARadius[I].x * AScale;
    RY[I] := ARadius[I].y * AScale;
    HX[I] := Max(0, ARadius[I].x - AShadow.Spread) * AScale;
    HY[I] := Max(0, ARadius[I].y - AShadow.Spread) * AScale;
    if (HX[I] = 0) or (HY[I] = 0) then begin HX[I] := 0; HY[I] := 0; end;
  end;
  N := SamplesPerAxis;
  Step := 1 / N;
  for Y := 0 to DH - 1 do
    for X := 0 to DW - 1 do begin
      CH := 0;
      CB := 0;
      for SY := 0 to N - 1 do
        for SX := 0 to N - 1 do begin
          PX := X + (SX + 0.5) * Step;
          PY := Y + (SY + 0.5) * Step;
          // hole: padding box moved by offset and reduced by spread
          if InRoundRect((Ext + AShadow.Spread + AShadow.X) * AScale, (Ext + AShadow.Spread + AShadow.Y) * AScale,
            (Ext + SW - AShadow.Spread + AShadow.X) * AScale, (Ext + SH - AShadow.Spread + AShadow.Y) * AScale, HX, HY, PX, PY) then CH := CH + 1;
          if InRoundRect(Ext * AScale, Ext * AScale, (Ext + SW) * AScale, (Ext + SH) * AScale, RX, RY, PX, PY) then CB := CB + 1;
        end;
      Mask[Y * DW + X] := 1 - CH / (N * N);
      BoxCov[Y * DW + X] := CB / (N * N);
    end;
  BlurMask(Mask, DW, DH, AShadow.Blur * AScale / 2);
  for I := 0 to DW * DH - 1 do Mask[I] := Mask[I] * BoxCov[I];
  XS[0] := Round(Ext * AScale);
  XS[3] := Round((Ext + SW) * AScale);
  YS[0] := XS[0];
  YS[3] := Round((Ext + SH) * AScale);
  if Result.Whole then begin
    Result.Parts[0] := Part(XS[0], YS[0], XS[3], YS[3]);
    Exit;
  end;
  Result.LW := M + RL;
  Result.RW := RR + M;
  Result.TH := M + RT;
  Result.BH := RB + M;
  XS[1] := XS[0] + Round(Result.LW * AScale); XS[2] := XS[3] - Round(Result.RW * AScale);
  YS[1] := YS[0] + Round(Result.TH * AScale); YS[2] := YS[3] - Round(Result.BH * AScale);
  for Y := 0 to 2 do
    for X := 0 to 2 do
      if (X = 1) and (Y = 1) then
        Result.Parts[4] := nil      // center is empty
      else if (X = 1) or (Y = 1) then
        Result.Parts[Y * 3 + X] := Part(IfThen(X = 1, XS[1], XS[X]), IfThen(Y = 1, YS[1], YS[Y]),
          IfThen(X = 1, XS[1] + 1, XS[X + 1]), IfThen(Y = 1, YS[1] + 1, YS[Y + 1]))
      else
        Result.Parts[Y * 3 + X] := Part(XS[X], YS[Y], XS[X + 1], YS[Y + 1]);
end;

procedure THtmlNode.PaintInsetShadow(ACanvas: TCanvas);
var
  Shadows: TCSSShadowArray;
  I, J, X, Idx, M: Integer;
  PB: TRect;
  P, R: array[0..3] of TPoint;
  BX, BY: array[0..3] of Integer;
  Sc: Single;
  Key: String;
  Slices: TCSSShadowSlices;
  C: TCSSRGBA;
  XS, YS: array[0..3] of Integer;
  procedure DrawPart(ABitmap: TBitmap; const ARect: TRect);
  begin
    if (ABitmap = nil) or (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
    DrawCachedBitmap(ACanvas, ARect, ABitmap);
  end;
begin
  {$ifndef fmx}
  if Pos('inset', FCompStyle.BoxShadow) = 0 then Exit;
  Shadows := ParseShadows(Trim(ResolveVars(FCompStyle.BoxShadow)));
  PB := PaddingBox;
  if (PB.Width <= 0) or (PB.Height <= 0) then Exit;
  with FCompSize.ContentRect do CalcRadius(Right - Left, Bottom - Top, P[0], P[1], P[2], P[3]);
  with FCompSize.Border do begin
    BX[0] := Left; BX[1] := Right; BX[2] := Right; BX[3] := Left;
    BY[0] := Top; BY[1] := Top; BY[2] := Bottom; BY[3] := Bottom;
  end;
  for J := 0 to 3 do begin          // inner radii of padding box
    R[J] := Point(Max(0, P[J].x - BX[J]), Max(0, P[J].y - BY[J]));
    if (R[J].x = 0) or (R[J].y = 0) then R[J] := Point(0, 0);
  end;
  Sc := RootNode.FPaintScale;
  if Sc <= 0 then Sc := 1;
  if CSSShadowCache = nil then begin
    CSSShadowCache := TCSSKeyList.Create;
    CSSShadowCache.Sorted := True;
    CSSShadowCache.OwnsObjects := True;
  end;
  for I := 0 to High(Shadows) do begin
    if not Shadows[I].Inset then Continue;
    C := CSSColorToRGBA(Shadows[I].Color);
    M := InsetMargin(Shadows[I]);
    Key := Format('I,%d,%d,%d,%d,%f,%s', [Shadows[I].Blur, Shadows[I].Spread, Shadows[I].X, Shadows[I].Y, Sc, RGBAKey(C)]);
    for J := 0 to 3 do Key := Key + Format(',%d,%d', [R[J].x, R[J].y]);
    if (PB.Width < Max(R[0].x, R[3].x) + Max(R[1].x, R[2].x) + 2 * M + 1) or
       (PB.Height < Max(R[0].y, R[1].y) + Max(R[3].y, R[2].y) + 2 * M + 1) then
      Key := Key + Format(',%d,%d', [PB.Width, PB.Height]);       // small node: whole shadow
    if CSSShadowCache.Find(Key, Idx) then
      Slices := TCSSShadowSlices(CSSShadowCache.Objects[Idx])
    else begin
      Slices := BuildInsetShadowSlices(PB.Width, PB.Height, R, Shadows[I], C, Sc);
      if CSSShadowCache.Count > CSS_CORNER_CACHE_LIMIT then CSSShadowCache.Clear;
      CSSShadowCache.AddObject(Key, Slices);
    end;
    if Slices.Whole then
      DrawPart(Slices.Parts[0], PB)
    else begin
      XS[0] := PB.Left; XS[1] := PB.Left + Slices.LW; XS[2] := PB.Right - Slices.RW; XS[3] := PB.Right;
      YS[0] := PB.Top; YS[1] := PB.Top + Slices.TH; YS[2] := PB.Bottom - Slices.BH; YS[3] := PB.Bottom;
      for J := 0 to 2 do
        for X := 0 to 2 do
          DrawPart(Slices.Parts[J * 3 + X], Rect(XS[X], YS[J], XS[X + 1], YS[J + 1]));
    end;
  end;
  {$endif}
end;

procedure THtmlNode.PaintBoxShadow(ACanvas: TCanvas);
var
  Shadows: TCSSShadowArray;
  I, J, X, Idx: Integer;
  Box, SR, O: TRect;
  P, R: array[0..3] of TPoint;
  Sc: Single;
  Key: String;
  Slices: TCSSShadowSlices;
  C: TCSSRGBA;
  XS, YS: array[0..3] of Integer;
  Opaque: Boolean;
  Inner: TRect;              // part of node which is surely covered by its background
  procedure DrawPart(ABitmap: TBitmap; const ARect: TRect);
  begin
    if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
    DrawCachedBitmap(ACanvas, ARect, ABitmap);
  end;
  // center of shadow under opaque node: only strips outside of node (offset, spread) are painted
  procedure DrawOutside(ABitmap: TBitmap; const ARect: TRect);
  var
    In_: TRect;
  begin
    In_ := TRect.Intersect(ARect, Inner);
    if In_.IsEmpty then begin
      DrawPart(ABitmap, ARect);
      Exit;
    end;
    DrawPart(ABitmap, Rect(ARect.Left, ARect.Top, ARect.Right, In_.Top));
    DrawPart(ABitmap, Rect(ARect.Left, In_.Bottom, ARect.Right, ARect.Bottom));
    DrawPart(ABitmap, Rect(ARect.Left, In_.Top, In_.Left, In_.Bottom));
    DrawPart(ABitmap, Rect(In_.Right, In_.Top, ARect.Right, In_.Bottom));
  end;
begin
  {$ifndef fmx}
  if FCompStyle.BoxShadow = '' then Exit;
  Shadows := ParseShadows(Trim(ResolveVars(FCompStyle.BoxShadow)));
  if Length(Shadows) = 0 then Exit;
  Box := FCompSize.ContentRect;
  if (Box.Width <= 0) or (Box.Height <= 0) then Exit;
  CalcRadius(Box.Width, Box.Height, P[0], P[1], P[2], P[3]);
  // opaque background covers shadow under node (corners of node are excluded)
  Opaque := (FCompStyle.Background.Color.ColorType = cctNormal) and (FCompStyle.Background.Color.Alpha = 255);
  Inner := Box;
  Inner.Left := Box.Left + Max(P[0].x, P[3].x);
  Inner.Right := Box.Right - Max(P[1].x, P[2].x);
  Inner.Top := Box.Top + Max(P[0].y, P[1].y);
  Inner.Bottom := Box.Bottom - Max(P[3].y, P[2].y);
  if (Inner.Width <= 0) or (Inner.Height <= 0) then Opaque := False;
  Sc := RootNode.FPaintScale;
  if Sc <= 0 then Sc := 1;
  if CSSShadowCache = nil then begin
    CSSShadowCache := TCSSKeyList.Create;
    CSSShadowCache.Sorted := True;
    CSSShadowCache.CaseSensitive := True;
    CSSShadowCache.OwnsObjects := True;
  end;
  for I := High(Shadows) downto 0 do begin   // first shadow is on top
    if Shadows[I].Inset then Continue;        // inset shadows are painted by PaintInsetShadow
    SR := Box;
    OffsetRect(SR, Shadows[I].X, Shadows[I].Y);
    InflateRect(SR, Shadows[I].Spread, Shadows[I].Spread);
    if (SR.Width <= 0) or (SR.Height <= 0) then Continue;
    for J := 0 to 3 do      // radius of shadow is increased by spread
      if (P[J].x > 0) and (P[J].y > 0) then R[J] := Point(Max(0, P[J].x + Shadows[I].Spread), Max(0, P[J].y + Shadows[I].Spread))
        else R[J] := Point(0, 0);
    C := CSSColorToRGBA(Shadows[I].Color);
    // template (9 parts) doesn't depend on shadow size, small shadows are rendered whole
    if (SR.Width >= Max(R[0].x, R[3].x) + Max(R[1].x, R[2].x) + 2 * Shadows[I].Blur + 1) and
       (SR.Height >= Max(R[0].y, R[1].y) + Max(R[3].y, R[2].y) + 2 * Shadows[I].Blur + 1) then
      Key := Format('T,%d,%f,%s', [Shadows[I].Blur, Sc, RGBAKey(C)])
    else
      Key := Format('%d,%d,%d,%f,%s', [SR.Width, SR.Height, Shadows[I].Blur, Sc, RGBAKey(C)]);
    for J := 0 to 3 do Key := Key + Format(',%d,%d', [R[J].x, R[J].y]);
    if CSSShadowCache.Find(Key, Idx) then
      Slices := TCSSShadowSlices(CSSShadowCache.Objects[Idx])
    else begin
      Slices := BuildShadowSlices(SR.Width, SR.Height, R, Shadows[I].Blur, C, Sc);
      if CSSShadowCache.Count > CSS_CORNER_CACHE_LIMIT then CSSShadowCache.Clear;
      CSSShadowCache.AddObject(Key, Slices);
    end;
    O := SR;
    InflateRect(O, Shadows[I].Blur, Shadows[I].Blur);
    if Slices.Whole then
      DrawPart(Slices.Parts[0], O)
    else begin
      XS[0] := O.Left; XS[1] := O.Left + Slices.LW; XS[2] := O.Right - Slices.RW; XS[3] := O.Right;
      YS[0] := O.Top; YS[1] := O.Top + Slices.TH; YS[2] := O.Bottom - Slices.BH; YS[3] := O.Bottom;
      for J := 0 to 2 do
        for X := 0 to 2 do
          if (J = 1) and (X = 1) and Opaque then
            DrawOutside(Slices.Parts[4], Rect(XS[1], YS[1], XS[2], YS[2]))
          else
            DrawPart(Slices.Parts[J * 3 + X], Rect(XS[X], YS[J], XS[X + 1], YS[J + 1]));
    end;
  end;
  {$endif}
end;

(*
  Antialiased dot for dotted borders (cached), ADiameter in device pixels
*)
function DotBitmap(ADiameter: Integer; AColor: TColor): TBitmap;
var
  Key: String;
  X, Y, SX, SY, N, Cov: Integer;
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
  R: Single;
  C: TCSSRGBA;
begin
  Key := Format('D%d,%x', [ADiameter, ColorToRGB(AColor)]);
  if CornerCache.Find(Key, X) then Exit(TBitmap(CSSCornerCache.Objects[X]));
  C := RGBAFromColor(AColor);
  N := 4;
  R := ADiameter / 2;
  Img := NewAlphaImage(ADiameter, ADiameter);
  try
    Wr := PixelWriter(Img);
    for Y := 0 to ADiameter - 1 do begin
      WriterLine(Wr, Y);
      for X := 0 to ADiameter - 1 do begin
        Cov := 0;
        for SY := 0 to N - 1 do
          for SX := 0 to N - 1 do
            if Sqr(X + (SX + 0.5) / N - R) + Sqr(Y + (SY + 0.5) / N - R) <= R * R then Inc(Cov);
        WritePixel(Wr, X, ToByte(C.R), ToByte(C.G), ToByte(C.B), Cov * 255 div (N * N));
      end;
    end;
    Result := IntfImageToBitmap(Img);
  finally
    Img.Free;
  end;
  AddPaintCache(Key, Result);
end;

(*
  Paint background and borders of node
  Straight parts are painted natively (FillRect, StretchDraw), corners are rasterized
*)
procedure THtmlNode.PaintBackgroundAndBorder(ACanvas: TCanvas);
type
  TBgKind = (bkNone, bkColor, bkAlphaColor, bkImage, bkAxisGradient, bkSoftware);
const
  KIND_SIDE: array[0..3] of TCSSSide = (csTop, csLeft, csBottom, csRight);   // order of colors in RasterizeShape
  CORNER_SIDE1: array[0..3] of TCSSSide = (csLeft, csTop, csRight, csBottom);  // adjacent sides of corners
  CORNER_SIDE2: array[0..3] of TCSSSide = (csTop, csRight, csBottom, csLeft);
var
  cs: TCSSItem;
  Box, R, ClipSave: TRect;
  W, H, I, J, Y0, Y1, LI, RI: Integer;
  P: array[0..3] of TPoint;
  CW, CH: array[0..3] of Integer;
  S, SS: TCSSPaintShape;
  BW: array[TCSSSide] of Integer;
  Side: TCSSSide;
  SideColor: array[TCSSSide] of TColor;
  SideVisible: array[TCSSSide] of Boolean;
  Colors: array[0..4] of TCSSRGBA;
  BgImage, Key, Url: String;
  Kind: TBgKind;
  Full, Repeating, AnyBorder: Boolean;
  Pat, PatD: TCSSSidePatterns;   // dashed/dotted patterns in canvas and device pixels
  Ys: array[0..5] of Integer;
  Slabs: array of TRect;
  Sc, FX, FY, TW, TH: Single;
  SCW, SCH: array[0..3] of Integer;
  Grad: TCSSGradient;
  Src: TCSSImageData;
  Dst: TRectF;
  OldAA: TAntialiasingMode;
  function ScaleRect(const ARect: TRect): TRect;
  begin
    Result := Rect(Round(ARect.Left * Sc), Round(ARect.Top * Sc), Round(ARect.Right * Sc), Round(ARect.Bottom * Sc));
  end;
  procedure DrawBitmap(const ARect: TRect; ABitmap: TBitmap);
  begin
    DrawCachedBitmap(ACanvas, ARect, ABitmap);   // high resolution bitmap (Retina)
  end;
  procedure SortYs;
  var
    A, B, T: Integer;
  begin
    for A := 0 to High(Ys) - 1 do
      for B := A + 1 to High(Ys) do
        if Ys[B] < Ys[A] then begin T := Ys[A]; Ys[A] := Ys[B]; Ys[B] := T; end;
  end;
  // dot with center CX, CY (canvas px), ADiameter in canvas px
  procedure DrawDot(CX, CY: Single; ADiameter: Integer; AColor: TColor);
  var
    D: Integer;
    DR: TRect;
  begin
    D := Max(1, Round(ADiameter * Sc));
    DR := Rect(Round(CX - ADiameter / 2), Round(CY - ADiameter / 2), Round(CX - ADiameter / 2) + ADiameter, Round(CY - ADiameter / 2) + ADiameter);
    if D <= 1 then begin
      ACanvas.Brush.Color := AColor;
      ACanvas.FillRect(DR);
    end else
      DrawBitmap(DR, DotBitmap(D, AColor));
  end;
  // straight part of side (corners are rasterized)
  procedure FillSide(ASide: TCSSSide; const ARect: TRect);
  var
    P: TCSSSidePattern;
    B0, B1, T0, T1, LX0, LX1: Single;
    K: Integer;
    RR: TRect;
    function LocalRect(AX0, AX1: Single): TRect;    // part of band from local X0 to X1
    begin
      case ASide of
        csTop: Result := Rect(Round(S.L + AX0), ARect.Top, Round(S.L + AX1), ARect.Bottom);
        csBottom: Result := Rect(Round(S.R - AX1), ARect.Top, Round(S.R - AX0), ARect.Bottom);
        csRight: Result := Rect(ARect.Left, Round(S.T + AX0), ARect.Right, Round(S.T + AX1));
        else Result := Rect(ARect.Left, Round(S.B - AX1), ARect.Right, Round(S.B - AX0));
      end;
    end;
  begin
    if not SideVisible[ASide] or (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
    ACanvas.Brush.Color := SideColor[ASide];
    P := Pat[ASide];
    // band in local coordinates
    case ASide of
      csTop: begin B0 := ARect.Left - S.L; B1 := ARect.Right - S.L; end;
      csBottom: begin B0 := S.R - ARect.Right; B1 := S.R - ARect.Left; end;
      csRight: begin B0 := ARect.Top - S.T; B1 := ARect.Bottom - S.T; end;
      else begin B0 := S.B - ARect.Bottom; B1 := S.B - ARect.Top; end;
    end;
    case P.Style of
      cbsDashed: begin
        if P.Gap < 0 then begin
          T0 := (P.Total - P.Dash) / 2;
          LX0 := Max(B0, P.Origin + T0 - P.A0);
          LX1 := Min(B1, P.Origin + T0 + P.Dash - P.A0);
          if LX1 > LX0 then ACanvas.FillRect(LocalRect(LX0, LX1));
        end else
          for K := 0 to Round(P.Total / (P.Dash + P.Gap)) + 1 do begin
            T0 := K * (P.Dash + P.Gap);
            T1 := T0 + P.Dash;
            LX0 := Max(B0, P.Origin + T0 - P.A0);
            LX1 := Min(B1, P.Origin + T1 - P.A0);
            if LX1 > LX0 then begin
              RR := LocalRect(LX0, LX1);
              if (RR.Right > RR.Left) and (RR.Bottom > RR.Top) then ACanvas.FillRect(RR);
            end;
          end;
      end;
      cbsDotted: ;    // dots are painted by PaintDots
      else
        ACanvas.FillRect(ARect);
    end;
  end;
  // dotted sides: whole antialiased dots on middle line of border (also in corners)
  procedure PaintDots;
  var
    Side: TCSSSide;
    K: Integer;
    C: TPointF;
    Saved: TRect;
  begin
    Saved := ACanvas.ClipRect;
    if TRect.Intersect(Box, Saved).IsEmpty then Exit;    // empty clip rect would mean "no clipping"
    SetCanvasClip(ACanvas, TRect.Intersect(Box, Saved));
    try
      for Side := Low(TCSSSide) to High(TCSSSide) do
        if SideVisible[Side] and (Pat[Side].Style = cbsDotted) then
          for K := 0 to Pat[Side].DotCount do begin
            C := DotCenter(S, Side, Pat[Side], K * Pat[Side].DotStep);
            DrawDot(C.x, C.y, BW[Side], SideColor[Side]);
          end;
    finally
      SetCanvasClip(ACanvas, Saved);
    end;
  end;
  function CornerRect(AIndex: Integer): TRect;
  begin
    case AIndex of
      0: Result := Rect(Box.Left, Box.Top, Box.Left + CW[0], Box.Top + CH[0]);
      1: Result := Rect(Box.Right - CW[1], Box.Top, Box.Right, Box.Top + CH[1]);
      2: Result := Rect(Box.Right - CW[2], Box.Bottom - CH[2], Box.Right, Box.Bottom);
      else Result := Rect(Box.Left, Box.Bottom - CH[3], Box.Left + CW[3], Box.Bottom);
    end;
  end;
  // background color with alpha in slab: 1x1 bitmap is stretched
  procedure FillAlpha(const ARect: TRect);
  var
    C: TCSSRGBA;
  begin
    C := CSSColorToRGBA(cs.Background.Color);
    if ToByte(C.A) = 0 then Exit;     // fully transparent bitmap is painted black on Windows (no alpha)
    DrawCachedBitmap(ACanvas, ARect, CSSAlphaBitmap(ToByte(C.R), ToByte(C.G), ToByte(C.B), ToByte(C.A)));
  end;
begin
  {$ifndef fmx}
  cs := FCompStyle;
  Box := FCompSize.ContentRect;
  W := Box.Width;
  H := Box.Height;
  if (W <= 0) or (H <= 0) then Exit;
  CalcRadius(W, H, P[0], P[1], P[2], P[3]);
  BW[csTop] := FCompSize.Border.Top;
  BW[csLeft] := FCompSize.Border.Left;
  BW[csBottom] := FCompSize.Border.Bottom;
  BW[csRight] := FCompSize.Border.Right;
  AnyBorder := False;
  for Side := Low(TCSSSide) to High(TCSSSide) do begin
    SideVisible[Side] := (BW[Side] > 0) and (cs.Border[Side].Color.ColorType <> cctTransparent);
    if cs.Border[Side].Color.ColorType = cctNormal then SideColor[Side] := EffectiveColor(cs.Border[Side].Color)
      else SideColor[Side] := EffectiveColor(cs.Color);      // currentcolor
    AnyBorder := AnyBorder or SideVisible[Side];
  end;

  // kind of background
  BgImage := '';
  if cs.Background.Image <> '' then BgImage := Trim(ResolveVars(cs.Background.Image));
  if SameText(BgImage, 'none') then BgImage := '';
  Src := nil;
  Kind := bkNone;
  if (cs.Background.Color.ColorType = cctNormal) and (cs.Background.Color.Alpha > 0) then begin
    if cs.Background.Color.Alpha = 255 then Kind := bkColor else Kind := bkAlphaColor;
  end;
  if BgImage <> '' then begin
    if ParseLinearGradient(BgImage, W, H, Grad) then begin
      if (Abs(Grad.DirX) < 1E-6) or (Abs(Grad.DirY) < 1E-6) then Kind := bkAxisGradient else Kind := bkSoftware;
    end else
    if SameText(Copy(BgImage, 1, 4), 'url(') then begin
      Url := Trim(StrBetween(BgImage, '(', ')'));
      Url := StringReplace(StringReplace(Url, '"', '', [rfReplaceAll]), '''', '', [rfReplaceAll]);
      Src := CSSLoadImage(Url);
      if Assigned(Src) and (Src.Width > 0) and (Src.Height > 0) then begin
        Kind := bkImage;
        {$if defined(windows) or defined(mswindows)}
        if Src.HasAlpha then Kind := bkSoftware;      // AlphaBlend can't stretch smoothly
        {$endif}
      end else
        Src := nil;
    end;
  end;

  // shape
  S.L := Box.Left; S.T := Box.Top; S.R := Box.Right; S.B := Box.Bottom;
  for Side := Low(TCSSSide) to High(TCSSSide) do S.BW[Side] := BW[Side];
  for I := 0 to 3 do begin
    S.RX[I] := P[I].x;
    S.RY[I] := P[I].y;
  end;
  // corner areas, these are rasterized
  CW[0] := Max(P[0].x, BW[csLeft]);  CH[0] := Max(P[0].y, BW[csTop]);
  CW[1] := Max(P[1].x, BW[csRight]); CH[1] := Max(P[1].y, BW[csTop]);
  CW[2] := Max(P[2].x, BW[csRight]); CH[2] := Max(P[2].y, BW[csBottom]);
  CW[3] := Max(P[3].x, BW[csLeft]);  CH[3] := Max(P[3].y, BW[csBottom]);
  for I := 0 to 3 do
    if (P[I].x = 0) and not AnyBorder then begin
      CW[I] := 0;
      CH[I] := 0;
    end;
  // bitmaps are rendered in device resolution
  Sc := RootNode.FPaintScale;
  if Sc <= 0 then Sc := 1;
  SS := S;
  SS.L := S.L * Sc; SS.T := S.T * Sc; SS.R := S.R * Sc; SS.B := S.B * Sc;
  for Side := Low(TCSSSide) to High(TCSSSide) do SS.BW[Side] := S.BW[Side] * Sc;
  for I := 0 to 3 do begin
    SS.RX[I] := S.RX[I] * Sc;
    SS.RY[I] := S.RY[I] * Sc;
  end;
  for Side := Low(TCSSSide) to High(TCSSSide) do begin
    Pat[Side] := MakeSidePattern(S, Side, cs.Border[Side].Style);
    PatD[Side] := MakeSidePattern(SS, Side, cs.Border[Side].Style);
  end;
  // corners overlap (small node, big borders), whole node is rasterized
  Full := (CW[0] + CW[1] > W) or (CW[3] + CW[2] > W) or (CH[0] + CH[3] > H) or (CH[1] + CH[2] > H) or
    (BW[csTop] + BW[csBottom] > H) or (BW[csLeft] + BW[csRight] > W);
  if Full and not (Kind in [bkNone, bkColor]) then Kind := bkSoftware;

  if Kind = bkSoftware then begin
    for I := 0 to 3 do
      if Full then begin
        SCW[I] := Round(W * Sc);
        SCH[I] := Round(H * Sc);
      end else begin
        SCW[I] := Round(CW[I] * Sc);
        SCH[I] := Round(CH[I] * Sc);
      end;
    DrawBitmap(Box, BackgroundLayer(SS, Round(W * Sc), Round(H * Sc), BgImage, SCW, SCH, Sc, 4,
      Rect(0, 0, Round(W * Sc), Round(H * Sc))));
  end;

  // colors for rasterized parts: background, top, left, bottom, right
  if Kind = bkColor then Colors[0] := RGBAFromColor(cs.Background.Color.Value) else Colors[0] := RGBAFromColor(0, 0);
  for I := 0 to 3 do
    if SideVisible[KIND_SIDE[I]] then Colors[I + 1] := RGBAFromColor(SideColor[KIND_SIDE[I]])
      else Colors[I + 1] := RGBAFromColor(0, 0);

  if Full then begin
    if (Kind = bkColor) or AnyBorder then begin
      Key := Format('F%d,%d,%d,%d,%d,%d,%d,%f', [W, H, BW[csTop], BW[csLeft], BW[csBottom], BW[csRight], Ord(CSSAntialiasing), Sc]);
      for I := 0 to 3 do Key := Key + Format(',%d,%d', [P[I].x, P[I].y]);
      for I := 0 to 4 do Key := Key + ',' + RGBAKey(Colors[I]);
      for Side := Low(TCSSSide) to High(TCSSSide) do Key := Key + ',' + PatternKey(PatD[Side]);
      DrawBitmap(Box, CornerBitmap(Key, SS, -1, ScaleRect(Box), Colors, PatD));
    end;
    PaintDots;
    Exit;
  end;

  ACanvas.Brush.Style := bsSolid;
  ACanvas.Pen.Style := psClear;
  // middle of background (without corners): horizontal slabs
  Slabs := nil;
  if Kind in [bkColor, bkAlphaColor, bkImage, bkAxisGradient] then begin
    Ys[0] := 0; Ys[1] := CH[0]; Ys[2] := CH[1]; Ys[3] := H - CH[3]; Ys[4] := H - CH[2]; Ys[5] := H;
    SortYs;
    for I := 0 to High(Ys) - 1 do begin
      Y0 := Ys[I];
      Y1 := Ys[I + 1];
      if Y1 <= Y0 then Continue;
      if Y0 < CH[0] then LI := CW[0] else if Y0 >= H - CH[3] then LI := CW[3] else LI := 0;
      if Y0 < CH[1] then RI := CW[1] else if Y0 >= H - CH[2] then RI := CW[2] else RI := 0;
      R := Rect(Box.Left + LI, Box.Top + Y0, Box.Right - RI, Box.Top + Y1);
      if R.Right > R.Left then begin
        SetLength(Slabs, Length(Slabs) + 1);
        Slabs[High(Slabs)] := R;
      end;
    end;
  end;
  // background color
  if (cs.Background.Color.ColorType = cctNormal) and (Kind in [bkColor, bkAlphaColor, bkImage]) then
    for I := 0 to High(Slabs) do
      if cs.Background.Color.Alpha = 255 then begin
        ACanvas.Brush.Color := cs.Background.Color.Value;
        ACanvas.FillRect(Slabs[I]);
      end else
        FillAlpha(Slabs[I]);
  // image or gradient, natively stretched and clipped to slabs
  if Kind in [bkImage, bkAxisGradient] then begin
    ClipSave := ACanvas.ClipRect;
    OldAA := ACanvas.AntialiasingMode;
    {$if defined(windows) or defined(mswindows)}
    ACanvas.AntialiasingMode := amOn;      // smooth stretching (HALFTONE), on macOS amOn disables interpolation
    {$endif}
    try
      if Kind = bkAxisGradient then begin
        Key := Format('%d,%d,%s,%s,%f', [W, H, BgImage, RGBAKey(CSSColorToRGBA(cs.Background.Color)), Sc]);
        for I := 0 to High(Slabs) do begin
          R := TRect.Intersect(Slabs[I], ClipSave);     // empty clip rect would mean "no clipping"
          if R.IsEmpty then Continue;
          SetCanvasClip(ACanvas, R);
          DrawCachedBitmap(ACanvas, Box, GradientStrip(Grad, Round(W * Sc), Round(H * Sc), Key));
        end;
      end else begin
        BackgroundImageRect(Src, W, H, Dst);
        Repeating := not SameText(Trim(cs.Background.RepeatMode), 'no-repeat');
        TW := Max(1, Dst.Width);
        TH := Max(1, Dst.Height);
        if Repeating then begin   // first tile
          Dst.Left := Dst.Left - Ceil(Dst.Left / TW) * TW;
          Dst.Top := Dst.Top - Ceil(Dst.Top / TH) * TH;
        end;
        for I := 0 to High(Slabs) do begin
          R := TRect.Intersect(Slabs[I], ClipSave);
          if R.IsEmpty then Continue;
          SetCanvasClip(ACanvas, R);
          FY := Dst.Top;
          J := 0;
          repeat
            FX := Dst.Left;
            repeat
              R := Rect(Box.Left + Round(FX), Box.Top + Round(FY), Box.Left + Round(FX + TW), Box.Top + Round(FY + TH));
              if R.IntersectsWith(Slabs[I]) then begin
                Inc(CSSStats.Bitmaps);
                ACanvas.StretchDraw(R, ImageBitmap(Src));
              end;
              FX := FX + TW;
              Inc(J);
            until not Repeating or (FX >= W) or (J > 4000);
            FY := FY + TH;
          until not Repeating or (FY >= H) or (J > 4000);
        end;
      end;
    finally
      SetCanvasClip(ACanvas, ClipSave);
      ACanvas.AntialiasingMode := OldAA;
    end;
  end;
  // corners of background (alpha color, image, gradient) are rasterized by software
  if Kind in [bkAlphaColor, bkImage, bkAxisGradient] then
    for I := 0 to 3 do
      if (CW[I] > 0) and (CH[I] > 0) then begin
        for J := 0 to 3 do begin
          SCW[J] := Round(CW[J] * Sc);
          SCH[J] := Round(CH[J] * Sc);
        end;
        R := CornerRect(I);
        DrawBitmap(R, BackgroundLayer(SS, Round(W * Sc), Round(H * Sc), BgImage, SCW, SCH, Sc, I,
          Rect(Round((R.Left - Box.Left) * Sc), Round((R.Top - Box.Top) * Sc), Round((R.Right - Box.Left) * Sc), Round((R.Bottom - Box.Top) * Sc))));
      end;
  // straight parts of borders
  FillSide(csTop, Rect(Box.Left + CW[0], Box.Top, Box.Right - CW[1], Box.Top + BW[csTop]));
  FillSide(csBottom, Rect(Box.Left + CW[3], Box.Bottom - BW[csBottom], Box.Right - CW[2], Box.Bottom));
  FillSide(csLeft, Rect(Box.Left, Box.Top + CH[0], Box.Left + BW[csLeft], Box.Bottom - CH[3]));
  FillSide(csRight, Rect(Box.Right - BW[csRight], Box.Top + CH[1], Box.Right, Box.Bottom - CH[2]));
  // corners (borders and solid background)
  if (Kind = bkColor) or AnyBorder then
    for I := 0 to 3 do begin
      if (CW[I] <= 0) or (CH[I] <= 0) then Continue;
      // empty corner (no background, no adjacent border): fully transparent bitmap would be black on Windows
      if (Kind <> bkColor) and not (SideVisible[CORNER_SIDE1[I]] or SideVisible[CORNER_SIDE2[I]]) then Continue;
      R := CornerRect(I);
      // key: corner geometry and colors of background and both adjacent sides
      Key := Format('%d,%d,%d,%d,%d,%d,%f', [I, CW[I], CH[I], P[I].x, P[I].y, Ord(CSSAntialiasing), Sc]);
      case I of
        0: Key := Key + Format(',%d,%d,%s,%s', [BW[csLeft], BW[csTop], RGBAKey(Colors[2]), RGBAKey(Colors[1])]);
        1: Key := Key + Format(',%d,%d,%s,%s', [BW[csRight], BW[csTop], RGBAKey(Colors[4]), RGBAKey(Colors[1])]);
        2: Key := Key + Format(',%d,%d,%s,%s', [BW[csRight], BW[csBottom], RGBAKey(Colors[4]), RGBAKey(Colors[3])]);
        3: Key := Key + Format(',%d,%d,%s,%s', [BW[csLeft], BW[csBottom], RGBAKey(Colors[2]), RGBAKey(Colors[3])]);
      end;
      Key := Key + ',' + RGBAKey(Colors[0]);
      case I of    // patterns of adjacent sides
        0: Key := Key + ',' + PatternKey(PatD[csLeft]) + ',' + PatternKey(PatD[csTop]);
        1: Key := Key + ',' + PatternKey(PatD[csTop]) + ',' + PatternKey(PatD[csRight]);
        2: Key := Key + ',' + PatternKey(PatD[csRight]) + ',' + PatternKey(PatD[csBottom]);
        3: Key := Key + ',' + PatternKey(PatD[csBottom]) + ',' + PatternKey(PatD[csLeft]);
      end;
      DrawBitmap(R, CornerBitmap(Key, SS, I, ScaleRect(R), Colors, PatD));
    end;
  PaintDots;
  {$endif}
end;

{ scrolling }

function THtmlNode.ClipsContent: Boolean;
begin
  Result := (FCompStyle.Overflow <> cotVisible) or (FCompStyle.OverflowY <> cotVisible);
end;

(*
  Padding box (border box without borders): viewport of scrolled content
*)
function THtmlNode.PaddingBox: TRect;
begin
  with FCompSize do
    Result := Rect(ContentRect.Left + Border.Left, ContentRect.Top + Border.Top, ContentRect.Right - Border.Right, ContentRect.Bottom - Border.Bottom);
end;

(*
  Scroll range from children positions (after layout). Content which overflows top/left (eg. justify-content: flex-end)
  has negative scroll position, so scroll position 0 is always initial position of content.
*)
procedure THtmlNode.UpdateScrollRange;
var
  VP, CB, AB: TRect;
  N: THtmlNode;
  Any, AnyAbs: Boolean;
begin
  FScrollMin := Point(0, 0);
  FScrollMax := Point(0, 0);
  if ClipsContent and (FChildCount > 0) then begin
    VP := PaddingBox;
    Any := False;
    AnyAbs := False;
    CB := VP;
    AB := VP;
    N := FFirstChild;
    while Assigned(N) do begin
      if (N.FCompStyle.Display <> cdtNone) and not N.IsWhiteSpaceText then
        if N.FCompStyle.Position in [cpAbsolute, cpFixed] then begin    // positioned in padding box
          if not AnyAbs then AB := N.FCompSize.MarginRect else AB.Union(N.FCompSize.MarginRect);
          AnyAbs := True;
        end else begin
          if not Any then CB := N.FCompSize.MarginRect else CB.Union(N.FCompSize.MarginRect);
          Any := True;
        end;
      N := N.FNextSibling;
    end;
    if Any or AnyAbs then begin
      if Any then begin           // padding around content
        Dec(CB.Top, FCompSize.Padding.Top);
        Dec(CB.Left, FCompSize.Padding.Left);
        Inc(CB.Bottom, FCompSize.Padding.Bottom);
        Inc(CB.Right, FCompSize.Padding.Right);
        if AnyAbs then CB.Union(AB);
      end else
        CB := AB;
      if FCompStyle.OverflowY <> cotVisible then begin
        FScrollMin.Y := Min(0, CB.Top - VP.Top);
        FScrollMax.Y := Max(0, CB.Bottom - VP.Bottom);
      end;
      if FCompStyle.Overflow <> cotVisible then begin
        FScrollMin.X := Min(0, CB.Left - VP.Left);
        FScrollMax.X := Max(0, CB.Right - VP.Right);
      end;
    end;
  end;
  FScrollX := EnsureRange(FScrollX, FScrollMin.X, FScrollMax.X);
  FScrollY := EnsureRange(FScrollY, FScrollMin.Y, FScrollMax.Y);
end;

(*
  User can scroll in this direction (overflow auto or scroll and position is not at the end)
*)
function THtmlNode.CanScroll(DX, DY: Integer): Boolean;
begin
  Result := False;
  if (DY <> 0) and (FCompStyle.OverflowY in [cotAuto, cotScroll]) then
    Result := ((DY < 0) and (FScrollY > FScrollMin.Y)) or ((DY > 0) and (FScrollY < FScrollMax.Y));
  if (DX <> 0) and (FCompStyle.Overflow in [cotAuto, cotScroll]) then
    Result := Result or ((DX < 0) and (FScrollX > FScrollMin.X)) or ((DX > 0) and (FScrollX < FScrollMax.X));
end;

function THtmlNode.ScrollBy(DX, DY: Integer): Boolean;
begin
  Result := SetScroll(FScrollX + DX, FScrollY + DY);
end;

(*
  Set scroll position (clamped to scroll range), returns True if position is changed
*)
function THtmlNode.SetScroll(AX, AY: Integer): Boolean;
var
  OX, OY: Integer;
begin
  OX := FScrollX;
  OY := FScrollY;
  FScrollX := EnsureRange(AX, FScrollMin.X, FScrollMax.X);
  FScrollY := EnsureRange(AY, FScrollMin.Y, FScrollMax.Y);
  Result := (OX <> FScrollX) or (OY <> FScrollY);
  if Result and Assigned(RootNode) then RootNode.UpdateStickyOffsets;
end;

(*
  position: sticky; top: N - node stays N px below top of its scroll container while it is scrolled,
  but it doesn't leave its parent (KISS: vertical only)
*)
function THtmlNode.StickyOffset: Integer;
var
  S, P: THtmlNode;
  Sum, Need, Limit: Integer;
begin
  Result := 0;
  Sum := 0;
  S := ParentNode;
  while Assigned(S) and not S.ClipsContent do begin
    Inc(Sum, S.FScrollY);
    S := S.ParentNode;
  end;
  if S = nil then Exit;
  Inc(Sum, S.FScrollY);
  Need := S.PaddingBox.Top + FCompSize.Position.Top - (FCompSize.ContentRect.Top - Sum);
  if Need <= 0 then Exit;
  P := ParentNode;
  if P = S then Limit := MaxInt div 2      // scroll container itself: whole scrolled content
  else Limit := P.FCompSize.ContentRect.Bottom - P.FCompSize.Border.Bottom - P.FCompSize.Padding.Bottom - FCompSize.MarginRect.Bottom;
  Result := Max(0, Min(Need, Limit));
end;

procedure THtmlNode.UpdateStickyOffsets;
  procedure Walk(N: THtmlNode);
  var
    C: THtmlNode;
  begin
    N.FStickyDY := 0;
    if (N.FCompStyle.Position = cpSticky) and N.FVisible and not (N.FCompStyle.Top.LengthType in [cltUndefined, cltAuto]) then
      N.FStickyDY := N.StickyOffset;
    C := N.FFirstChild;
    while Assigned(C) do begin
      Walk(C);
      C := C.FNextSibling;
    end;
  end;
begin
  Walk(Self);
end;

(*
  Children in paint order (z-index, then order in tree)
*)
function THtmlNode.PaintOrder: THtmlNodeArray;
var
  N, T: THtmlNode;
  I, J: Integer;
  Sorted: Boolean;
  // sticky node is painted above its siblings (as positioned node)
  function PaintZ(ANode: THtmlNode): Integer;
  begin
    Result := ANode.FCompStyle.ZIndex;
    if (Result = 0) and (ANode.FCompStyle.Position = cpSticky) then Result := 1;
  end;
begin
  SetLength(Result, FChildCount);
  I := 0;
  Sorted := True;
  N := FFirstChild;
  while Assigned(N) and (I < Length(Result)) do begin
    Result[I] := N;
    if (N.FCompStyle.ZIndex <> 0) or (N.FCompStyle.Position = cpSticky) then Sorted := False;
    Inc(I);
    N := N.FNextSibling;
  end;
  SetLength(Result, I);
  if Sorted then Exit;
  for I := 1 to High(Result) do begin    // stable insertion sort
    T := Result[I];
    J := I - 1;
    while (J >= 0) and (PaintZ(Result[J]) > PaintZ(T)) do begin
      Result[J + 1] := Result[J];
      Dec(J);
    end;
    Result[J + 1] := T;
  end;
end;

(*
  Overlay scrollbars (thin rounded thumbs like on macOS)
*)
procedure THtmlNode.PaintScrollbars(ACanvas: TCanvas);
const
  SIZE = 6;
  GAP = 2;
var
  VP: TRect;
  Len, Range, TL, TP: Integer;
  procedure DrawThumb(const ARect: TRect);
  var
    S: TCSSPaintShape;
    Colors: array[0..4] of TCSSRGBA;
    Pat: TCSSSidePatterns;
    I: Integer;
    Sc: Single;
    D: TRect;
  begin
    if (ARect.Width <= 0) or (ARect.Height <= 0) then Exit;
    Sc := RootNode.FPaintScale;
    if Sc <= 0 then Sc := 1;
    D := Rect(0, 0, Round(ARect.Width * Sc), Round(ARect.Height * Sc));
    S := Default(TCSSPaintShape);
    S.R := D.Right;
    S.B := D.Bottom;
    for I := 0 to 3 do begin
      S.RX[I] := Min(D.Right, D.Bottom) / 2;
      S.RY[I] := S.RX[I];
    end;
    Colors[0] := RGBAFromColor(clBlack, 0.35);
    for I := 1 to 4 do Colors[I] := RGBAFromColor(0, 0);
    Pat := Default(TCSSSidePatterns);
    DrawCachedBitmap(ACanvas, ARect, CornerBitmap(Format('SB%d,%d', [D.Right, D.Bottom]), S, -1, D, Colors, Pat));
  end;
begin
  FVThumb := Rect(0, 0, 0, 0);
  FHThumb := Rect(0, 0, 0, 0);
  VP := PaddingBox;
  if (FCompStyle.OverflowY in [cotAuto, cotScroll]) and (FScrollMax.Y > FScrollMin.Y) and (VP.Height > 4 * SIZE) then begin
    Len := VP.Height - 2 * GAP;
    Range := FScrollMax.Y - FScrollMin.Y;
    TL := Max(3 * SIZE, Round(Len * Len / (Len + Range)));
    TP := VP.Top + GAP + Round((FScrollY - FScrollMin.Y) / Range * (Len - TL));
    FVThumb := Rect(VP.Right - SIZE - GAP, TP, VP.Right - GAP, TP + TL);
    DrawThumb(FVThumb);
  end;
  if (FCompStyle.Overflow in [cotAuto, cotScroll]) and (FScrollMax.X > FScrollMin.X) and (VP.Width > 4 * SIZE) then begin
    Len := VP.Width - 2 * GAP;
    Range := FScrollMax.X - FScrollMin.X;
    TL := Max(3 * SIZE, Round(Len * Len / (Len + Range)));
    TP := VP.Left + GAP + Round((FScrollX - FScrollMin.X) / Range * (Len - TL));
    FHThumb := Rect(TP, VP.Bottom - SIZE - GAP, TP + TL, VP.Bottom - GAP);
    DrawThumb(FHThumb);
  end;
end;

(*
  Position of scroll thumb for dragging: 1 = vertical, 2 = horizontal, 0 = not on thumb
*)
function THtmlNode.ThumbAt(const APos: TPoint): Integer;
begin
  if PtInRect(FVThumb, APos) then Result := 1
  else if PtInRect(FHThumb, APos) then Result := 2
  else Result := 0;
end;

(*
  Scroll by moving thumb by ADelta pixels
*)
function THtmlNode.ScrollByThumb(AAxis, AStartScroll, ADelta: Integer): Boolean;
var
  VP: TRect;
  Len, Range, TL: Integer;
begin
  VP := PaddingBox;
  if AAxis = 1 then begin
    Len := VP.Height - 4;
    Range := FScrollMax.Y - FScrollMin.Y;
  end else begin
    Len := VP.Width - 4;
    Range := FScrollMax.X - FScrollMin.X;
  end;
  TL := Max(18, Round(Len * Len / Max(1, Len + Range)));
  if Len - TL <= 0 then Exit(False);
  if AAxis = 1 then Result := SetScroll(FScrollX, AStartScroll + Round(ADelta * Range / (Len - TL)))
    else Result := SetScroll(AStartScroll + Round(ADelta * Range / (Len - TL)), FScrollY);
end;

function THtmlNode.HasFocusWithin: Boolean;
var
  N: THtmlNode;
begin
  if FFocused then Exit(True);
  N := FFirstChild;
  while Assigned(N) do begin
    if N.HasFocusWithin then Exit(True);
    N := N.FNextSibling;
  end;
  Result := False;
end;

{ transforms }

function MatIdentity: TCSSMatrix2D;
begin
  Result.A := 1; Result.B := 0; Result.C := 0; Result.D := 1; Result.E := 0; Result.F := 0;
end;

function Mat(A, B, C, D, E, F: Single): TCSSMatrix2D;
begin
  Result.A := A; Result.B := B; Result.C := C; Result.D := D; Result.E := E; Result.F := F;
end;

(*
  M1 * M2: M2 is applied first
*)
function MatMul(const M1, M2: TCSSMatrix2D): TCSSMatrix2D;
begin
  Result.A := M1.A * M2.A + M1.C * M2.B;
  Result.B := M1.B * M2.A + M1.D * M2.B;
  Result.C := M1.A * M2.C + M1.C * M2.D;
  Result.D := M1.B * M2.C + M1.D * M2.D;
  Result.E := M1.A * M2.E + M1.C * M2.F + M1.E;
  Result.F := M1.B * M2.E + M1.D * M2.F + M1.F;
end;

function MatApply(const M: TCSSMatrix2D; const P: TPointF): TPointF;
begin
  Result.x := M.A * P.x + M.C * P.y + M.E;
  Result.y := M.B * P.x + M.D * P.y + M.F;
end;

function MatInvert(const M: TCSSMatrix2D; out AResult: TCSSMatrix2D): Boolean;
var
  Det: Single;
begin
  Det := M.A * M.D - M.B * M.C;
  Result := Abs(Det) > 1E-9;
  if not Result then begin
    AResult := MatIdentity;
    Exit;
  end;
  AResult.A := M.D / Det;
  AResult.B := -M.B / Det;
  AResult.C := -M.C / Det;
  AResult.D := M.A / Det;
  AResult.E := -(AResult.A * M.E + AResult.C * M.F);
  AResult.F := -(AResult.B * M.E + AResult.D * M.F);
end;

(*
  Angle in radians: deg, rad, turn, grad, 0
*)
function CSSToAngle(AValue: String; out AAngle: Single): Boolean;
var
  F: Single;
begin
  AValue := LowerCase(Trim(AValue));
  Result := True;
  if AValue.EndsWith('deg') and CSSStrToFloat(Copy(AValue, 1, Length(AValue) - 3), F) then AAngle := F * CSS_DEG_RAD
  else if AValue.EndsWith('grad') and CSSStrToFloat(Copy(AValue, 1, Length(AValue) - 4), F) then AAngle := F * Pi / 200
  else if AValue.EndsWith('rad') and CSSStrToFloat(Copy(AValue, 1, Length(AValue) - 3), F) then AAngle := F
  else if AValue.EndsWith('turn') and CSSStrToFloat(Copy(AValue, 1, Length(AValue) - 4), F) then AAngle := F * 2 * Pi
  else if CSSStrToFloat(AValue, F) and (F = 0) then AAngle := 0
  else Result := False;
end;

function CSSToScale(AValue: String; out AScale: Single): Boolean;
begin
  AValue := Trim(AValue);
  if AValue.EndsWith('%') then begin
    Result := CSSStrToFloat(Copy(AValue, 1, Length(AValue) - 1), AScale);
    AScale := AScale / 100;
  end else
    Result := CSSStrToFloat(AValue, AScale);
end;

(*
  Transform of node relative to its border box (top left corner is 0, 0)
  https://developer.mozilla.org/en-US/docs/Web/CSS/transform
*)
procedure THtmlNode.ComputeTransform;
var
  W, H: Integer;
  M: TCSSMatrix2D;
  S, Name, Args: String;
  Parts: TStringArray;
  I, P, Level: Integer;
  X, Y, A: Single;
  OX, OY: Single;
  function Len(const AValue: String; ARef: Integer): Single;
  var
    L: TCSSLength;
  begin
    Result := 0;
    if TryCSSToLengthValue(AValue, L) and (L.LengthType <> cltAuto) then begin
      if L.LengthType = cltPercentage then Result := L.Value / 100 * ARef
      else Result := CalcLength(L, ARef);
    end;
  end;
  function Arg(AIndex: Integer): String;
  begin
    if AIndex <= High(Parts) then Result := Trim(Parts[AIndex]) else Result := '';
  end;
  procedure Apply(const AM: TCSSMatrix2D);
  begin
    M := MatMul(M, AM);
  end;
  procedure ApplyFunction(const AName: String);
  var
    SX, SY: Single;
  begin
    Parts := SplitParameters(StringReplace(Args, ',', ' ', [rfReplaceAll]));
    if AName = 'translate' then Apply(Mat(1, 0, 0, 1, Len(Arg(0), W), Len(Arg(1), H)))
    else if AName = 'translatex' then Apply(Mat(1, 0, 0, 1, Len(Arg(0), W), 0))
    else if AName = 'translatey' then Apply(Mat(1, 0, 0, 1, 0, Len(Arg(0), H)))
    else if AName = 'scale' then begin
      if not CSSToScale(Arg(0), SX) then SX := 1;
      if not CSSToScale(Arg(1), SY) then SY := SX;
      Apply(Mat(SX, 0, 0, SY, 0, 0));
    end
    else if AName = 'scalex' then begin
      if CSSToScale(Arg(0), SX) then Apply(Mat(SX, 0, 0, 1, 0, 0));
    end
    else if AName = 'scaley' then begin
      if CSSToScale(Arg(0), SY) then Apply(Mat(1, 0, 0, SY, 0, 0));
    end
    else if AName = 'rotate' then begin
      if CSSToAngle(Arg(0), A) then Apply(Mat(Cos(A), Sin(A), -Sin(A), Cos(A), 0, 0));
    end
    else if (AName = 'skew') or (AName = 'skewx') or (AName = 'skewy') then begin
      if not CSSToAngle(Arg(0), SX) then SX := 0;
      if (AName = 'skew') and CSSToAngle(Arg(1), SY) then else SY := 0;
      if AName = 'skewy' then begin SY := SX; SX := 0; end;
      Apply(Mat(1, Tan(SY), Tan(SX), 1, 0, 0));
    end
    else if (AName = 'matrix') and (Length(Parts) = 6) then
      Apply(Mat(CSSStrToFloatDef(Parts[0], 1), CSSStrToFloatDef(Parts[1], 0), CSSStrToFloatDef(Parts[2], 0),
        CSSStrToFloatDef(Parts[3], 1), CSSStrToFloatDef(Parts[4], 0), CSSStrToFloatDef(Parts[5], 0)));
  end;
  // transformation from styles, animated transformation is shown
  procedure SetTarget(const AM: TCSSMatrix2D);
  var
    Done: Boolean;
  begin
    FTransformTarget := AM;
    FTransform := AM;
    if Assigned(FAnim) and (RootNode.FRenderScale = 1) then begin     // not in offscreen layout of transformed parent
      if FAnim^.MatrixPending then begin
        FAnim^.MatrixTo := AM;
        FAnim^.MatrixPending := False;
        FAnim^.MatrixOn := True;
      end else
      if FAnim^.MatrixOn then
        FAnim^.MatrixTo := AM;
      ApplyAnimation(GetTickCount64, Done);
    end;
    UpdateTransformKind;
  end;
begin
  FTransformKind := tkNone;
  FTransform := MatIdentity;
  FTransformTarget := MatIdentity;
  if FLayoutRoot then Exit;
  if (FCompStyle.Transform = '') and (FCompStyle.Translate = '') and (FCompStyle.Rotate = '') and (FCompStyle.Scale = '') then begin
    SetTarget(MatIdentity);
    Exit;
  end;
  W := FCompSize.ContentRect.Width;
  H := FCompSize.ContentRect.Height;
  // transform-origin, default center
  OX := W / 2;
  OY := H / 2;
  if FCompStyle.TransformOrigin <> '' then begin
    Parts := SplitParameters(LowerCase(Trim(FCompStyle.TransformOrigin)));
    for I := 0 to Min(1, High(Parts)) do begin
      S := Parts[I];
      if S = 'left' then OX := 0 else if S = 'right' then OX := W
      else if S = 'top' then OY := 0 else if S = 'bottom' then OY := H
      else if S = 'center' then begin if I = 0 then OX := W / 2 else OY := H / 2; end
      else if I = 0 then OX := Len(S, W) else OY := Len(S, H);
    end;
  end;
  M := Mat(1, 0, 0, 1, OX, OY);
  // individual transform properties: translate, rotate, scale (in this order), then transform
  S := Trim(ResolveVars(FCompStyle.Translate));
  if (S <> '') and (S <> 'none') then begin
    Args := S;
    ApplyFunction('translate');
  end;
  S := Trim(ResolveVars(FCompStyle.Rotate));
  if (S <> '') and (S <> 'none') then begin
    Args := S;
    ApplyFunction('rotate');
  end;
  S := Trim(ResolveVars(FCompStyle.Scale));
  if (S <> '') and (S <> 'none') then begin
    Args := S;
    ApplyFunction('scale');
  end;
  S := Trim(ResolveVars(FCompStyle.Transform));
  if (S <> '') and not SameText(S, 'none') then begin
    // list of functions: name(args) name(args) ...
    I := 1;
    while I <= Length(S) do begin
      while (I <= Length(S)) and (S[I] in [' ', #9, ',']) do Inc(I);
      P := I;
      while (I <= Length(S)) and (S[I] <> '(') do Inc(I);
      if I > Length(S) then Break;
      Name := LowerCase(Trim(Copy(S, P, I - P)));
      Inc(I);
      P := I;
      Level := 1;
      while (I <= Length(S)) and (Level > 0) do begin
        if S[I] = '(' then Inc(Level) else if S[I] = ')' then Dec(Level);
        Inc(I);
      end;
      Args := Copy(S, P, I - P - 1);
      ApplyFunction(Name);
    end;
  end;
  M := MatMul(M, Mat(1, 0, 0, 1, -OX, -OY));
  SetTarget(M);
end;

procedure THtmlNode.UpdateTransformKind;
var
  M: TCSSMatrix2D;
begin
  M := FTransform;
  FTransformKind := tkNone;
  if (Abs(M.A - 1) < 1E-6) and (Abs(M.B) < 1E-6) and (Abs(M.C) < 1E-6) and (Abs(M.D - 1) < 1E-6) then begin
    if (Abs(M.E) >= 0.5) or (Abs(M.F) >= 0.5) then FTransformKind := tkTranslate;
  end else
    FTransformKind := tkGeneral;
  if (FCompStyle.Opacity < 0.999) and not FLayoutRoot then FTransformKind := tkGeneral;   // painted through bitmap with alpha
  // bitmaps of scaled, rotated or transparent node are released when it is painted directly again (end of animation)
  if (FTransformKind <> tkGeneral) and not FLayoutRoot and (Assigned(FTransformBmp) or (FTransformSrc <> nil)) then begin
    FreeAndNil(FTransformBmp);
    FTransformSrc := nil;
    FTransformSrcKey := '';
    FTransformKey := '';
  end;
end;

{ animations }

(*
  Minimal animations (KISS): transitions of colors, opacity and transform (hover, focus, class changes) and
  built-in animations spin, ping, pulse, bounce (as in Tailwind CSS). There are no @keyframes. Animation
  changes only painted values (layout is not changed), TCSSShape repaints animated area with a timer.
*)
var
  CSSAnimNodes: TList;       // nodes with running animation (all trees)

function TimingFromName(const AName: String): TCSSTiming;
var
  P: TStringArray;
  procedure SetT(X1, Y1, X2, Y2: Single);
  begin
    Result.X1 := X1; Result.Y1 := Y1; Result.X2 := X2; Result.Y2 := Y2;
  end;
begin
  if AName = 'linear' then SetT(0, 0, 1, 1)
  else if AName = 'ease-in' then SetT(0.42, 0, 1, 1)
  else if AName = 'ease-out' then SetT(0, 0, 0.58, 1)
  else if AName = 'ease-in-out' then SetT(0.42, 0, 0.58, 1)
  else if Copy(AName, 1, 13) = 'cubic-bezier(' then begin
    P := SplitParameters(Copy(AName, 14, Length(AName) - 14), ',');
    SetT(0.25, 0.1, 0.25, 1);
    if Length(P) = 4 then
      SetT(CSSStrToFloatDef(Trim(P[0]), 0), CSSStrToFloatDef(Trim(P[1]), 0), CSSStrToFloatDef(Trim(P[2]), 1), CSSStrToFloatDef(Trim(P[3]), 1));
  end
  else SetT(0.25, 0.1, 0.25, 1);    // ease
end;

function MakeTiming(X1, Y1, X2, Y2: Single): TCSSTiming;
begin
  Result.X1 := X1; Result.Y1 := Y1; Result.X2 := X2; Result.Y2 := Y2;
end;

(*
  Value of cubic-bezier timing function at X (0..1)
*)
function TimingValue(const T: TCSSTiming; X: Single): Single;
  function Bez(U, A, B: Single): Single; inline;
  begin
    Result := 3 * Sqr(1 - U) * U * A + 3 * (1 - U) * U * U * B + U * U * U;
  end;
  function BezD(U, A, B: Single): Single; inline;
  begin
    Result := 3 * Sqr(1 - U) * A + 6 * (1 - U) * U * (B - A) + 3 * U * U * (1 - B);
  end;
var
  U, D, E: Single;
  I: Integer;
begin
  if X <= 0 then Exit(0);
  if X >= 1 then Exit(1);
  U := X;
  for I := 1 to 8 do begin     // Newton: U for X
    E := Bez(U, T.X1, T.X2) - X;
    if Abs(E) < 1E-4 then Break;
    D := BezD(U, T.X1, T.X2);
    if Abs(D) < 1E-6 then Break;
    U := EnsureRange(U - E / D, 0, 1);
  end;
  Result := Bez(U, T.Y1, T.Y2);
end;

procedure GetColorChannels(AStyle: TCSSItem; out AColors: TCSSColorChannels);
begin
  AColors[0] := AStyle.Background.Color;
  AColors[1] := AStyle.Color;
  AColors[2] := AStyle.Border[csTop].Color;
  AColors[3] := AStyle.Border[csRight].Color;
  AColors[4] := AStyle.Border[csBottom].Color;
  AColors[5] := AStyle.Border[csLeft].Color;
end;

procedure SetColorChannel(AStyle: TCSSItem; AIndex: Integer; const AColor: TCSSColor);
begin
  case AIndex of
    0: AStyle.Background.Color := AColor;
    1: AStyle.Color := AColor;
    2: AStyle.Border[csTop].Color := AColor;
    3: AStyle.Border[csRight].Color := AColor;
    4: AStyle.Border[csBottom].Color := AColor;
    5: AStyle.Border[csLeft].Color := AColor;
  end;
end;

function SameCSSColor(const A, B: TCSSColor): Boolean;
begin
  Result := (A.ColorType = B.ColorType) and ((A.ColorType <> cctNormal) or ((A.Value = B.Value) and (A.Alpha = B.Alpha)));
end;

// colors which can be interpolated (no background = transparent)
function CanLerpColor(const A, B: TCSSColor; AIndex: Integer): Boolean;
  function Ok(const C: TCSSColor): Boolean;
  begin
    Result := (C.ColorType in [cctNormal, cctTransparent]) or ((AIndex = 0) and (C.ColorType = cctUndefined));
  end;
begin
  Result := Ok(A) and Ok(B);
end;

// interpolation of premultiplied colors (as browsers)
function LerpColor(const A, B: TCSSColor; T: Single): TCSSColor;
var
  CA, CB: TCSSRGBA;
  Al: Single;
  function Ch(X, Y: Single): Byte;
  begin
    Result := EnsureRange(Round((X * CA.A + (Y * CB.A - X * CA.A) * T) / Al * 255), 0, 255);
  end;
begin
  CA := CSSColorToRGBA(A);
  CB := CSSColorToRGBA(B);
  Al := CA.A + (CB.A - CA.A) * T;
  Result.ColorType := cctNormal;
  if Al <= 0.002 then begin
    Result.Value := 0;
    Result.Alpha := 0;
    Exit;
  end;
  Result.Value := RGBToColor(Ch(CA.R, CB.R), Ch(CA.G, CB.G), Ch(CA.B, CB.B));
  Result.Alpha := EnsureRange(Round(Al * 255), 0, 255);
end;

function MatLerp(const A, B: TCSSMatrix2D; T: Single): TCSSMatrix2D;
begin
  Result.A := A.A + (B.A - A.A) * T;
  Result.B := A.B + (B.B - A.B) * T;
  Result.C := A.C + (B.C - A.C) * T;
  Result.D := A.D + (B.D - A.D) * T;
  Result.E := A.E + (B.E - A.E) * T;
  Result.F := A.F + (B.F - A.F) * T;
end;

function MatScale(const M: TCSSMatrix2D): Single;
begin
  Result := Max(Sqrt(Sqr(M.A) + Sqr(M.B)), Sqrt(Sqr(M.C) + Sqr(M.D)));
end;

(*
  animation: spin 1s linear infinite -> 1 (spin), ADuration = 1000
*)
function BuiltinAnimation(const AValue: String; out ADuration: Integer): Integer;
var
  Parts: TStringArray;
  I: Integer;
begin
  Result := 0;
  ADuration := 0;
  if AValue = '' then Exit;
  Parts := SplitParameters(AValue, ' ');
  for I := 0 to High(Parts) do
    if Parts[I] = 'spin' then Result := 1
    else if Parts[I] = 'ping' then Result := 2
    else if Parts[I] = 'pulse' then Result := 3
    else if Parts[I] = 'bounce' then Result := 4
    else if IsCSSTime(Parts[I]) and (ADuration = 0) then ADuration := CSSToTime(Parts[I]);
  if ADuration <= 0 then
    if Result = 3 then ADuration := 2000 else ADuration := 1000;
end;

function THtmlNode.Animating: Boolean;
var
  I: Integer;
begin
  Result := False;
  if CSSAnimNodes = nil then Exit;
  for I := 0 to CSSAnimNodes.Count - 1 do
    if THtmlNode(CSSAnimNodes[I]).RootNode = Self then Exit(True);
end;

function THtmlNode.AnimationTick(ANow: QWord): Boolean;
var
  I: Integer;
  N: THtmlNode;
  Done: Boolean;
begin
  Result := False;
  if CSSAnimNodes = nil then Exit;
  for I := CSSAnimNodes.Count - 1 downto 0 do begin
    if I >= CSSAnimNodes.Count then Continue;
    N := THtmlNode(CSSAnimNodes[I]);
    if N.RootNode <> Self then Continue;
    Result := True;
    N.ApplyAnimation(ANow, Done);
    if Done then N.StopAnimation;
  end;
end;

function THtmlNode.AnimationBounds: TRect;
var
  I: Integer;
  N: THtmlNode;
  R: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if CSSAnimNodes = nil then Exit;
  for I := 0 to CSSAnimNodes.Count - 1 do begin
    N := THtmlNode(CSSAnimNodes[I]);
    if (N.RootNode <> Self) or not N.FVisible then Continue;
    R := N.FCompSize.ContentRect;
    if N.FCompStyle.BoxShadow <> '' then InflateRect(R, 60, 60) else InflateRect(R, 2, 2);
    R := N.TransformedBounds(R);
    if Result.IsEmpty then Result := R else Result := TRect.Union(Result, R);
  end;
end;

function THtmlNode.AnimatingTransitions: Boolean;
var
  I, J: Integer;
  A: PCSSAnim;
begin
  Result := False;
  if CSSAnimNodes = nil then Exit;
  for I := 0 to CSSAnimNodes.Count - 1 do
    if THtmlNode(CSSAnimNodes[I]).RootNode = Self then begin
      A := THtmlNode(CSSAnimNodes[I]).FAnim;
      if A^.OpacityOn or A^.MatrixOn or A^.MatrixPending then Exit(True);
      for J := 0 to 5 do
        if A^.ColorOn[J] then Exit(True);
    end;
end;

function THtmlNode.AnimationRects: TCSSRectArray;
var
  I: Integer;
  N: THtmlNode;
  R: TRect;
begin
  Result := nil;
  if CSSAnimNodes = nil then Exit;
  for I := 0 to CSSAnimNodes.Count - 1 do begin
    N := THtmlNode(CSSAnimNodes[I]);
    if (N.RootNode <> Self) or not N.FVisible then Continue;
    R := N.PaintedRect;
    if not R.IsEmpty then begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := R;
    end;
  end;
end;

procedure THtmlNode.StopAnimation;
begin
  if FAnim = nil then Exit;
  if Assigned(CSSAnimNodes) then CSSAnimNodes.Remove(Self);
  Dispose(FAnim);
  FAnim := nil;
end;

function THtmlNode.AnimMaxScale: Single;
begin
  Result := 1;
  if FAnim = nil then Exit;
  if FAnim^.MatrixOn or FAnim^.MatrixPending then Result := Max(MatScale(FAnim^.MatrixFrom), MatScale(FAnim^.MatrixTo));
  if FAnim^.Frames = 2 then Result := Max(Result, 2 * MatScale(FTransformTarget));    // ping scales to 2
end;

(*
  Styles were applied: start transitions of changed values (AOld* are values shown before)
*)
procedure THtmlNode.UpdateTransitions(const AOldColors: TCSSColorChannels; AOldOpacity: Single; const AOldMatrix: TCSSMatrix2D);
var
  cs: TCSSItem;
  Props, Sig: TStringArray;
  TSig: String;
  NewColors: TCSSColorChannels;
  NewOn: array[0..5] of Boolean;
  I, Frames, FramesDur: Integer;
  Transition, Restart, OpacityOn, MatrixNew, Done: Boolean;
  Now: QWord;
  function Has(const AName: String): Boolean;
  var
    K: Integer;
  begin
    for K := 0 to High(Props) do
      if (Trim(Props[K]) = AName) or (Trim(Props[K]) = 'all') then Exit(True);
    Result := False;
  end;
  function ChannelEnabled(AIndex: Integer): Boolean;
  begin
    case AIndex of
      0: Result := Has('background-color') or Has('background');
      1: Result := Has('color');
      else Result := Has('border-color') or Has('border');
    end;
  end;
begin
  cs := FCompStyle;
  Now := GetTickCount64;
  TSig := ResolveVars(cs.Transform) + '|' + ResolveVars(cs.Translate) + '|' + ResolveVars(cs.Rotate) + '|' + ResolveVars(cs.Scale);
  Frames := 0;
  if CSSAnimationsEnabled then Frames := BuiltinAnimation(cs.Animation, FramesDur);
  Transition := CSSAnimationsEnabled and FStyled and (cs.TransitionDuration > 0) and (cs.TransitionProperty <> 'none');
  if not Transition and (Frames = 0) then begin
    StopAnimation;
    FTransformSig := TSig;
    Exit;
  end;
  if FAnim = nil then begin
    New(FAnim);
    FillChar(FAnim^, SizeOf(TCSSAnim), 0);
    if CSSAnimNodes = nil then CSSAnimNodes := TList.Create;
    CSSAnimNodes.Add(Self);
  end;
  if FAnim^.Frames <> Frames then FAnim^.FramesStart := Now;
  FAnim^.Frames := Frames;
  FAnim^.FramesDuration := FramesDur;
  FAnim^.BaseOpacity := cs.Opacity;
  Restart := False;
  OpacityOn := False;
  MatrixNew := False;
  GetColorChannels(cs, NewColors);
  Props := SplitParameters(cs.TransitionProperty, ',');
  for I := 0 to 5 do begin
    NewOn[I] := Transition and ChannelEnabled(I) and CanLerpColor(AOldColors[I], NewColors[I], I) and
      ((FAnim^.ColorOn[I] and SameCSSColor(FAnim^.ColorTo[I], NewColors[I])) or not SameCSSColor(AOldColors[I], NewColors[I]));
    if NewOn[I] and not (FAnim^.ColorOn[I] and SameCSSColor(FAnim^.ColorTo[I], NewColors[I])) then Restart := True;
  end;
  if Transition and Has('opacity') then begin
    OpacityOn := (FAnim^.OpacityOn and (FAnim^.OpacityTo = cs.Opacity)) or (Abs(AOldOpacity - cs.Opacity) > 0.001);
    if OpacityOn and not (FAnim^.OpacityOn and (FAnim^.OpacityTo = cs.Opacity)) then Restart := True;
  end;
  if Transition and (Has('transform') or Has('translate') or Has('scale') or Has('rotate')) and (TSig <> FTransformSig) then begin
    MatrixNew := True;
    Restart := True;
  end;
  FTransformSig := TSig;
  if Restart then begin      // all running values continue from shown values
    FAnim^.Start := Now;
    FAnim^.Duration := cs.TransitionDuration;
    FAnim^.Delay := cs.TransitionDelay;
    FAnim^.Timing := TimingFromName(cs.TransitionTiming);
    for I := 0 to 5 do begin
      if NewOn[I] then begin
        FAnim^.ColorFrom[I] := AOldColors[I];
        FAnim^.ColorTo[I] := NewColors[I];
      end;
      FAnim^.ColorOn[I] := NewOn[I];
    end;
    if OpacityOn then begin
      FAnim^.OpacityFrom := AOldOpacity;
      FAnim^.OpacityTo := cs.Opacity;
    end;
    FAnim^.OpacityOn := OpacityOn;
    if MatrixNew or FAnim^.MatrixOn then FAnim^.MatrixFrom := AOldMatrix;
    if MatrixNew then FAnim^.MatrixPending := True;
  end else begin
    for I := 0 to 5 do FAnim^.ColorOn[I] := NewOn[I];
    FAnim^.OpacityOn := OpacityOn;
  end;
  if not Transition then begin
    FAnim^.MatrixOn := False;
    FAnim^.MatrixPending := False;
  end;
  ApplyAnimation(Now, Done);       // shown values (cascade has set target values)
  if Done then StopAnimation;
end;

(*
  Animated values at time ANow are written to computed style and FTransform
*)
procedure THtmlNode.ApplyAnimation(ANow: QWord; out ADone: Boolean);
var
  A: PCSSAnim;
  P, E, Op, Q, CX, CY, Y: Single;
  M, X: TCSSMatrix2D;
  I: Integer;
  procedure InheritColor(N: THtmlNode; AAnimated: Boolean);
  var
    C: THtmlNode;
  begin
    C := N.FFirstChild;
    while Assigned(C) do begin
      if not (cipColor in C.FCompStyle.Specified) then begin
        C.FCompStyle.Color := N.FCompStyle.Color;
        C.FColorAnimated := AAnimated;
        InheritColor(C, AAnimated);
      end;
      C := C.FNextSibling;
    end;
  end;
begin
  A := FAnim;
  ADone := True;
  if A = nil then Exit;
  if A^.Duration > 0 then P := EnsureRange((Int64(ANow) - Int64(A^.Start) - A^.Delay) / A^.Duration, 0, 1) else P := 1;
  E := TimingValue(A^.Timing, P);
  for I := 0 to 5 do
    if A^.ColorOn[I] then
      if P >= 1 then SetColorChannel(FCompStyle, I, A^.ColorTo[I])
        else SetColorChannel(FCompStyle, I, LerpColor(A^.ColorFrom[I], A^.ColorTo[I], E));
  if A^.ColorOn[1] then InheritColor(Self, P < 1);   // text of descendants (eg. anonymous text node) has the same color
  if A^.OpacityOn then Op := A^.OpacityFrom + (A^.OpacityTo - A^.OpacityFrom) * E else Op := A^.BaseOpacity;
  if A^.MatrixOn then M := MatLerp(A^.MatrixFrom, A^.MatrixTo, E)
  else if A^.MatrixPending then M := A^.MatrixFrom
  else M := FTransformTarget;
  // built-in keyframes (Tailwind CSS animate-*)
  if (A^.Frames > 0) and (A^.FramesDuration > 0) then begin
    Q := ((ANow - A^.FramesStart) mod QWord(A^.FramesDuration)) / A^.FramesDuration;
    CX := FCompSize.ContentRect.Width / 2;
    CY := FCompSize.ContentRect.Height / 2;
    X := MatIdentity;
    case A^.Frames of
      1: X := Mat(Cos(2 * Pi * Q), Sin(2 * Pi * Q), -Sin(2 * Pi * Q), Cos(2 * Pi * Q), 0, 0);    // spin
      2: begin                                                                                  // ping
        Q := TimingValue(MakeTiming(0, 0, 0.2, 1), Min(Q / 0.75, 1));
        X := Mat(1 + Q, 0, 0, 1 + Q, 0, 0);
        Op := Op * (1 - Q);
      end;
      3: if Q < 0.5 then Op := Op * (1 - 0.5 * TimingValue(MakeTiming(0.4, 0, 0.6, 1), Q * 2))     // pulse
           else Op := Op * (0.5 + 0.5 * TimingValue(MakeTiming(0.4, 0, 0.6, 1), (Q - 0.5) * 2));
      4: begin                                                                                  // bounce
        if Q < 0.5 then Y := -0.25 * FCompSize.ContentRect.Height * (1 - TimingValue(MakeTiming(0.8, 0, 1, 1), Q * 2))
          else Y := -0.25 * FCompSize.ContentRect.Height * TimingValue(MakeTiming(0, 0, 0.2, 1), (Q - 0.5) * 2);
        X := Mat(1, 0, 0, 1, 0, Y);
      end;
    end;
    M := MatMul(M, MatMul(Mat(1, 0, 0, 1, CX, CY), MatMul(X, Mat(1, 0, 0, 1, -CX, -CY))));
  end;
  FCompStyle.Opacity := Op;
  FTransform := M;
  UpdateTransformKind;
  if P >= 1 then begin
    for I := 0 to 5 do A^.ColorOn[I] := False;
    A^.OpacityOn := False;
    A^.MatrixOn := False;
  end;
  ADone := (P >= 1) and (A^.Frames = 0) and not A^.MatrixPending;
end;

(*
  Point in canvas coordinates transformed by node transformation and back
*)
function THtmlNode.TransformPoint(const P: TPointF): TPointF;
var
  TL: TPointF;
begin
  if FTransformKind = tkNone then Exit(P);
  TL := PointF(FCompSize.ContentRect.Left, FCompSize.ContentRect.Top);
  Result := MatApply(FTransform, PointF(P.x - TL.x, P.y - TL.y));
  Result.x := Result.x + TL.x;
  Result.y := Result.y + TL.y;
end;

function THtmlNode.UntransformPoint(const P: TPointF): TPointF;
var
  TL: TPointF;
  Inv: TCSSMatrix2D;
begin
  if (FTransformKind = tkNone) or not MatInvert(FTransform, Inv) then Exit(P);
  TL := PointF(FCompSize.ContentRect.Left, FCompSize.ContentRect.Top);
  Result := MatApply(Inv, PointF(P.x - TL.x, P.y - TL.y));
  Result.x := Result.x + TL.x;
  Result.y := Result.y + TL.y;
end;

(*
  Point on screen to point in layout coordinates of this node (inverse transformations of all parents)
*)
function THtmlNode.ScreenToLayout(const P: TPointF): TPointF;
var
  InClip: Boolean;
begin
  Result := ScreenToLayoutClip(P, InClip);
end;

(*
  Point on screen to layout coordinates of this node: inverse transformations and scroll positions of parents
  AVisible is False if point is outside of clipped (overflow) area of some parent
*)
function THtmlNode.ScreenToLayoutClip(const P: TPointF; out AVisible: Boolean): TPointF;
var
  Chain: array of THtmlNode;
  N: THtmlNode;
  I: Integer;
  VP: TRect;
begin
  Chain := nil;
  N := Self;
  while Assigned(N) do begin
    SetLength(Chain, Length(Chain) + 1);
    Chain[High(Chain)] := N;
    N := N.ParentNode;
  end;
  Result := P;
  AVisible := True;
  for I := High(Chain) downto 0 do begin    // from root to node
    N := Chain[I];
    Result.y := Result.y - N.FStickyDY;
    Result := N.UntransformPoint(Result);
    if I > 0 then begin                     // parent: clipping and scrolling of its children
      if N.ClipsContent then begin
        VP := N.PaddingBox;
        if (Result.x < VP.Left) or (Result.x >= VP.Right) or (Result.y < VP.Top) or (Result.y >= VP.Bottom) then AVisible := False;
      end;
      Result.x := Result.x + N.FScrollX;
      Result.y := Result.y + N.FScrollY;
    end;
  end;
end;

(*
  Point in layout coordinates of this node to screen (transformations of node and parents, scroll positions)
*)
function THtmlNode.LayoutToScreen(const P: TPointF): TPointF;
var
  N: THtmlNode;
begin
  Result := P;
  N := Self;
  while Assigned(N) do begin
    Result := N.TransformPoint(Result);
    Result.y := Result.y + N.FStickyDY;
    if Assigned(N.ParentNode) then begin
      Result.x := Result.x - N.ParentNode.FScrollX;
      Result.y := Result.y - N.ParentNode.FScrollY;
    end;
    N := N.ParentNode;
  end;
end;

(*
  Visible area of node on screen (clipped by parents with overflow)
*)
function THtmlNode.ScreenClipRect: TRect;
var
  N: THtmlNode;
begin
  Result := Rect(-MaxInt div 2, -MaxInt div 2, MaxInt div 2, MaxInt div 2);
  N := ParentNode;
  while Assigned(N) do begin
    if N.ClipsContent then Result := TRect.Intersect(Result, N.TransformedBounds(N.PaddingBox));
    N := N.ParentNode;
  end;
end;

(*
  Bounding box of transformed rectangle
*)
function THtmlNode.TransformedBounds(const ARect: TRect): TRect;
var
  P: array[0..3] of TPointF;
begin
  P[0] := LayoutToScreen(PointF(ARect.Left, ARect.Top));
  P[1] := LayoutToScreen(PointF(ARect.Right, ARect.Top));
  P[2] := LayoutToScreen(PointF(ARect.Right, ARect.Bottom));
  P[3] := LayoutToScreen(PointF(ARect.Left, ARect.Bottom));
  Result := Rect(Round(Min(Min(P[0].x, P[1].x), Min(P[2].x, P[3].x))), Round(Min(Min(P[0].y, P[1].y), Min(P[2].y, P[3].y))),
    Round(Max(Max(P[0].x, P[1].x), Max(P[2].x, P[3].x))), Round(Max(Max(P[0].y, P[1].y), Max(P[2].y, P[3].y))));
end;


procedure THtmlNode.OffsetSubtree(DX, DY: Integer);
var
  N: THtmlNode;
begin
  OffsetRect(FCompSize.ContentRect, DX, DY);
  OffsetRect(FCompSize.MarginRect, DX, DY);
  N := FFirstChild;
  while Assigned(N) do begin
    N.OffsetSubtree(DX, DY);
    N := N.FNextSibling;
  end;
end;

(*
  Paint node and its children
*)
procedure THtmlNode.PaintNodeTree(ACanvas: TCanvas; const AClipRect: TRect);
var
  N: THtmlNode;
  DX, DY, I: Integer;
  Clip: TRect;
  Children: THtmlNodeArray;
  SavedClip: TCSSClipCorners;
  // rounded corners of padding box clip children (only children touching corners are rounded, KISS)
  procedure SetClipCorners;
  var
    P: array[0..3] of TPoint;
    BX, BY: array[0..3] of Integer;
    J: Integer;
  begin
    with FCompSize.ContentRect do CalcRadius(Right - Left, Bottom - Top, P[0], P[1], P[2], P[3]);
    if (P[0].x = 0) and (P[1].x = 0) and (P[2].x = 0) and (P[3].x = 0) then Exit;   // parent clip stays
    with FCompSize.Border do begin
      BX[0] := Left; BX[1] := Right; BX[2] := Right; BX[3] := Left;
      BY[0] := Top; BY[1] := Top; BY[2] := Bottom; BY[3] := Bottom;
    end;
    CSSPaintClip.Active := True;
    CSSPaintClip.Box := PaddingBox;
    for J := 0 to 3 do begin
      CSSPaintClip.RX[J] := Max(0, P[J].x - BX[J]);
      CSSPaintClip.RY[J] := Max(0, P[J].y - BY[J]);
      if CSSPaintClip.RY[J] = 0 then CSSPaintClip.RX[J] := 0;
    end;
  end;
begin
  if not FVisible then Exit;
  FStyled := True;
  if (FCompStyle.Opacity <= 0.004) and not FLayoutRoot then Exit;     // opacity: 0
  if FStickyDY <> 0 then begin         // sticky node: painted moved (as translate)
    DX := FStickyDY;
    FStickyDY := 0;
    OffsetSubtree(0, DX);
    try
      PaintNodeTree(ACanvas, AClipRect);
    finally
      OffsetSubtree(0, -DX);
      FStickyDY := DX;
    end;
    Exit;
  end;
  case FTransformKind of
    tkTranslate: begin       // translated node is painted directly (exact, no bitmap)
      DX := Round(FTransform.E);
      DY := Round(FTransform.F);
      FTransformKind := tkNone;
      OffsetSubtree(DX, DY);
      try
        PaintNodeTree(ACanvas, AClipRect);
      finally
        OffsetSubtree(-DX, -DY);
        FTransformKind := tkTranslate;
      end;
      Exit;
    end;
    tkGeneral: begin
      SavedClip := CSSPaintClip;          // transformed node is painted in its own coordinates
      CSSPaintClip.Active := False;
      try
        PaintTransformed(ACanvas, AClipRect);
      finally
        CSSPaintClip := SavedClip;
      end;
      Exit;
    end;
  end;
  // colors in transition change every frame: bitmaps of corners and icons are not cached
  CSSPaintTransient := FColorAnimated or Assigned(FAnim) and (FAnim^.ColorOn[0] or FAnim^.ColorOn[1] or
    FAnim^.ColorOn[2] or FAnim^.ColorOn[3] or FAnim^.ColorOn[4] or FAnim^.ColorOn[5]);
  try
    DrawNode(ACanvas, AClipRect);
  finally
    CSSPaintTransient := False;
    FreePaintTemp;
  end;
  if FChildCount > 0 then begin
    SavedClip := CSSPaintClip;
    if ClipsContent then begin
      Clip := TRect.Intersect(PaddingBox, AClipRect);
      SetClipCorners;
    end else
      Clip := AClipRect;
    try
      Children := PaintOrder;
      for I := 0 to High(Children) do begin
        N := Children[I];
        if (FScrollX <> 0) or (FScrollY <> 0) then begin   // scrolled content
          N.OffsetSubtree(-FScrollX, -FScrollY);
          try
            N.PaintNodeTree(ACanvas, Clip);
          finally
            N.OffsetSubtree(FScrollX, FScrollY);
          end;
        end else
          N.PaintNodeTree(ACanvas, Clip);
      end;
    finally
      CSSPaintClip := SavedClip;
    end;
    if ((FScrollMax.X > FScrollMin.X) or (FScrollMax.Y > FScrollMin.Y)) and not FCompStyle.ScrollbarNone then begin
      SetCanvasClip(ACanvas, AClipRect);
      PaintScrollbars(ACanvas);
    end;
  end;
end;

procedure THtmlNode.SaveLayout(var AStates: TCSSLayoutStates);
var
  N: THtmlNode;
  I: Integer;
begin
  SetLength(AStates, Length(AStates) + 1);
  I := High(AStates);
  AStates[I].Node := Self;
  AStates[I].ContentRect := FCompSize.ContentRect;
  AStates[I].MarginRect := FCompSize.MarginRect;
  AStates[I].Margin := FCompSize.Margin;
  AStates[I].Padding := FCompSize.Padding;
  AStates[I].Border := FCompSize.Border;
  AStates[I].Position := FCompSize.Position;
  AStates[I].BaseLine := FCompSize.BaseLine;
  AStates[I].ContentWidth := FCompSize.ContentWidth;
  AStates[I].ContentHeight := FCompSize.ContentHeight;
  AStates[I].FontSize := FCompSize.FontSize;
  AStates[I].Transform := FTransform;
  AStates[I].TransformTarget := FTransformTarget;
  AStates[I].Kind := FTransformKind;
  AStates[I].Visible := FVisible;
  AStates[I].LayoutRoot := FLayoutRoot;
  AStates[I].LayoutWidth := FLayoutWidth;
  AStates[I].LayoutHeight := FLayoutHeight;
  N := FFirstChild;
  while Assigned(N) do begin
    N.SaveLayout(AStates);
    N := N.FNextSibling;
  end;
end;

procedure RestoreLayout(const AStates: TCSSLayoutStates);
var
  I: Integer;
begin
  for I := 0 to High(AStates) do
    with AStates[I], Node do begin
      FCompSize.ContentRect := ContentRect;
      FCompSize.MarginRect := MarginRect;
      FCompSize.Margin := Margin;
      FCompSize.Padding := Padding;
      FCompSize.Border := Border;
      FCompSize.Position := Position;
      FCompSize.BaseLine := BaseLine;
      FCompSize.ContentWidth := ContentWidth;
      FCompSize.ContentHeight := ContentHeight;
      FCompSize.FontSize := FontSize;
      FTransform := Transform;
      FTransformTarget := TransformTarget;
      FTransformKind := Kind;
      FVisible := Visible;
      FLayoutRoot := LayoutRoot;
      FLayoutWidth := LayoutWidth;
      FLayoutHeight := LayoutHeight;
    end;
end;

(*
  Scaled, rotated or skewed node: node with children is painted to bitmap and the bitmap is transformed
  On macOS the bitmap is transparent (canvas keeps alpha), on other widgetsets it is painted on black and white
  background, so alpha is known also without alpha support in canvas (GDI).
  Result is cached until styles or layout of node are changed.
*)
procedure THtmlNode.PaintTransformed(ACanvas: TCanvas; const AClipRect: TRect);
var
  R, CB: TRect;
  E, I, X, Y, DW, DH, SW, SH: Integer;
  Shadows: TCSSShadowArray;
  Sc, U, V, FX, FY, W00, W10, W01, W11: Single;
  Key, SrcKey: String;
  Black, White: TLazIntfImage;
  Opa: Single;
  NonEmpty: Boolean;
  Pts: array[0..3] of TPointF;
  MAbs, Inv: TCSSMatrix2D;
  Img: TLazIntfImage;
  Wr: TCSSPixelWriter;
  P: TPointF;
  X0, Y0, X1, Y1: Integer;
  PA, PR, PG, PB: Single;
  OldScale, OldRatio, K: Single;
  Uniform: Boolean;
  KR: TRect;                // source rect in layout of resolution K
  KSW, KSH: Integer;
  States: TCSSLayoutStates;
  Sig: LongWord;
  procedure SubtreeSignature(ANode: THtmlNode; AX, AY: Integer; var AHash: LongWord);
  var
    N: THtmlNode;
  begin
    {$push}{$Q-}{$R-}
    with ANode.FCompSize.ContentRect do
      AHash := ((AHash * 31 + LongWord(Left - AX)) * 31 + LongWord(Top - AY)) * 31 + LongWord(Right - Left) * 7 + LongWord(Bottom - Top);
    {$pop}
    N := ANode.FFirstChild;
    while Assigned(N) do begin
      SubtreeSignature(N, AX, AY, AHash);
      N := N.FNextSibling;
    end;
  end;
  // AColor = clNone: transparent bitmap (canvas keeps alpha on macOS)
  function RenderOn(AColor: TColor): TLazIntfImage;
  var
    Bmp: TBitmap;
    Tmp: TLazIntfImage;
  begin
    Bmp := TBitmap.Create;
    try
      if AColor = clNone then begin
        Tmp := NewAlphaImage(KSW, KSH);
        try
          Tmp.FillPixels(colTransparent);
          Bmp.LoadFromIntfImage(Tmp);
        finally
          Tmp.Free;
        end;
      end else begin
        Bmp.SetSize(KSW, KSH);
        Bmp.Canvas.Brush.Color := AColor;
        Bmp.Canvas.FillRect(0, 0, KSW, KSH);
      end;
      OffsetSubtree(-KR.Left, -KR.Top);
      FTransformKind := tkNone;
      try
        PaintNodeTree(Bmp.Canvas, Rect(0, 0, KSW, KSH));
      finally
        FTransformKind := tkGeneral;
        OffsetSubtree(KR.Left, KR.Top);
      end;
      Result := Bmp.CreateIntfImage;
    finally
      Bmp.Free;
    end;
  end;
  function Sample(SX, SY: Integer): LongWord; inline;
  begin
    if (SX < 0) or (SY < 0) or (SX >= KSW) or (SY >= KSH) then Result := 0 else Result := FTransformSrc[SY * KSW + SX];
  end;
  function Ch(AP: LongWord; AShift: Byte): Single; inline;
  begin
    Result := (AP shr AShift) and $FF;
  end;
var
  C00, C10, C01, C11: LongWord;
  CB0, CW0: TFPColor;
  A: Integer;
begin
  {$ifndef fmx}
  Sc := RootNode.FPaintScale;
  if Sc <= 0 then Sc := 1;
  // painted area of node: border box and shadows
  E := 1;
  Shadows := ParseShadows(Trim(ResolveVars(FCompStyle.BoxShadow)));
  for I := 0 to High(Shadows) do
    E := Max(E, Max(Abs(Shadows[I].X), Abs(Shadows[I].Y)) + Shadows[I].Blur + Max(0, Shadows[I].Spread) + 1);
  R := FCompSize.ContentRect;
  InflateRect(R, E, E);
  SW := R.Width;
  SH := R.Height;
  if (SW <= 0) or (SH <= 0) then Exit;
  // layout of children relative to node (cache is valid when node is only moved)
  Sig := 0;
  SubtreeSignature(Self, FCompSize.ContentRect.Left, FCompSize.ContentRect.Top, Sig);
  // transformation in canvas coordinates
  MAbs := MatMul(Mat(1, 0, 0, 1, FCompSize.ContentRect.Left, FCompSize.ContentRect.Top),
    MatMul(FTransform, Mat(1, 0, 0, 1, -FCompSize.ContentRect.Left, -FCompSize.ContentRect.Top)));
  if not MatInvert(MAbs, Inv) then Exit;
  Pts[0] := MatApply(MAbs, PointF(R.Left, R.Top));
  Pts[1] := MatApply(MAbs, PointF(R.Right, R.Top));
  Pts[2] := MatApply(MAbs, PointF(R.Right, R.Bottom));
  Pts[3] := MatApply(MAbs, PointF(R.Left, R.Bottom));
  CB := Rect(Floor(Min(Min(Pts[0].x, Pts[1].x), Min(Pts[2].x, Pts[3].x))), Floor(Min(Min(Pts[0].y, Pts[1].y), Min(Pts[2].y, Pts[3].y))),
    Ceil(Max(Max(Pts[0].x, Pts[1].x), Max(Pts[2].x, Pts[3].x))), Ceil(Max(Max(Pts[0].y, Pts[1].y), Max(Pts[2].y, Pts[3].y))));
  if (CB.Width <= 0) or (CB.Height <= 0) or (CB.Width > 8000) or (CB.Height > 8000) then Exit;

  // resolution K of source: node is laid out again with pixel ratio * K, so text and borders are sharp also when
  // node is scaled up or on Retina display. During animation K is the largest scale (source is rendered once).
  K := Sc * Max(1, Max(MatScale(FTransform), AnimMaxScale));
  K := Min(K, 4);
  if Assigned(FAnim) then K := Ceil(K * 4 - 0.01) / 4;
  SrcKey := Format('%d,%f,%d,%d,%d,%d,%.3f', [CSSPaintGeneration, Sc, E, SW, SH, Sig, K]);
  Opa := FCompStyle.Opacity;
  Key := Format('%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.3f', [SrcKey,
    FTransform.A, FTransform.B, FTransform.C, FTransform.D, FTransform.E, FTransform.F,
    CB.Left - FCompSize.ContentRect.Left + (CB.Top - FCompSize.ContentRect.Top) * 65536, Opa]);
  if not (Assigned(FTransformBmp) and (FTransformKey = Key)) then begin
    FreeAndNil(FTransformBmp);
    FTransformKey := Key;
    if FTransformSrcKey <> SrcKey then begin
    // source: node painted on black and white (or transparent) in resolution K
    OldScale := RootNode.FPaintScale;
    OldRatio := RootNode.FPixelRatio;
    States := nil;
    KR := R;
    if Abs(K - 1) > 0.01 then begin
      SaveLayout(States);
      RootNode.FPixelRatio := OldRatio * K;
      RootNode.FRenderScale := K;
      LayoutTo(0, 0, Round(FCompSize.MarginRect.Width * K), Round(FCompSize.MarginRect.Height * K));
      KR := FCompSize.ContentRect;
      InflateRect(KR, Round(E * K), Round(E * K));
    end;
    KSW := KR.Width;
    KSH := KR.Height;
    RootNode.FPaintScale := 1;
    White := nil;
    try
      {$ifdef darwin}
      Black := RenderOn(clNone);       // macOS canvas keeps alpha channel (exact antialiased text)
      {$else}
      Black := RenderOn(clBlack);      // other widgetsets (GDI) don't write alpha: alpha from black and white
      White := RenderOn(clWhite);
      {$endif}
    finally
      RootNode.FPaintScale := OldScale;
      RootNode.FPixelRatio := OldRatio;
      RootNode.FRenderScale := 1;
      if Length(States) > 0 then RestoreLayout(States);
    end;
    try
      FTransformSrcKey := SrcKey;
      FTransformSrcW := KSW;
      FTransformSrcH := KSH;
      SetLength(FTransformSrc, KSW * KSH);
      for Y := 0 to KSH - 1 do
        for X := 0 to KSW - 1 do begin
          CB0 := Black.Colors[X, Y];
          if White = nil then begin     // transparent render (macOS returns premultiplied colors)
            A := CB0.Alpha shr 8;
            FTransformSrc[Y * KSW + X] := (LongWord(A) shl 24) or (LongWord(Min(A, CB0.Red shr 8)) shl 16) or
              (LongWord(Min(A, CB0.Green shr 8)) shl 8) or LongWord(Min(A, CB0.Blue shr 8));
            Continue;
          end;
          CW0 := White.Colors[X, Y];
          // alpha from difference, color on black is premultiplied color
          A := 255 - ((CW0.Red shr 8 - CB0.Red shr 8) + (CW0.Green shr 8 - CB0.Green shr 8) + (CW0.Blue shr 8 - CB0.Blue shr 8)) div 3;
          A := EnsureRange(A, 0, 255);
          FTransformSrc[Y * KSW + X] := (LongWord(A) shl 24) or (LongWord(Min(A, CB0.Red shr 8)) shl 16) or
            (LongWord(Min(A, CB0.Green shr 8)) shl 8) or LongWord(Min(A, CB0.Blue shr 8));
        end;
    finally
      Black.Free;
      White.Free;
    end;
    end;
    KSW := FTransformSrcW;
    KSH := FTransformSrcH;
    // destination in device pixels: inverse mapping with bilinear sampling
    Uniform := (Abs(FTransform.B) < 1E-6) and (Abs(FTransform.C) < 1E-6) and (Abs(Abs(FTransform.A) - Abs(FTransform.D)) < 1E-6) and
      (Abs(Abs(FTransform.A) * Sc - KSW / SW) < 0.02);
    DW := Round(CB.Width * Sc);
    DH := Round(CB.Height * Sc);
    Img := NewAlphaImage(DW, DH);
    NonEmpty := False;
    try
      Wr := PixelWriter(Img);
      // only moved (opacity, translate): source pixels are copied (fast path, eg. animated opacity)
      if Uniform and (Abs(FTransform.A - 1) < 1E-6) and (Abs(FTransform.D - 1) < 1E-6) then begin
        P := MatApply(Inv, PointF(CB.Left + 0.5 / Sc, CB.Top + 0.5 / Sc));
        X0 := Round((P.x - R.Left) * KSW / SW - 0.5);
        Y0 := Round((P.y - R.Top) * KSH / SH - 0.5);
        for Y := 0 to DH - 1 do begin
          WriterLine(Wr, Y);
          for X := 0 to DW - 1 do begin
            C00 := Sample(X0 + X, Y0 + Y);
            A := C00 shr 24;
            if Round(A * Opa) = 0 then WritePixel(Wr, X, 0, 0, 0, 0)
            else begin
              WritePixel(Wr, X, Min(255, ((C00 shr 16) and $FF) * 255 div A), Min(255, ((C00 shr 8) and $FF) * 255 div A),
                Min(255, (C00 and $FF) * 255 div A), Round(A * Opa));
              NonEmpty := True;
            end;
          end;
        end;
      end else
      for Y := 0 to DH - 1 do begin
        WriterLine(Wr, Y);
        for X := 0 to DW - 1 do begin
          P := MatApply(Inv, PointF(CB.Left + (X + 0.5) / Sc, CB.Top + (Y + 0.5) / Sc));
          U := (P.x - R.Left) * KSW / SW - 0.5;      // source pixel (resolution K)
          V := (P.y - R.Top) * KSH / SH - 0.5;
          if Uniform then begin    // source has same resolution as destination: nearest pixel (sharp text)
            U := Round(U);
            V := Round(V);
          end;
          X0 := Floor(U); Y0 := Floor(V);
          if (X0 < -1) or (Y0 < -1) or (X0 >= KSW) or (Y0 >= KSH) then begin
            WritePixel(Wr, X, 0, 0, 0, 0);
            Continue;
          end;
          X1 := X0 + 1; Y1 := Y0 + 1;
          FX := U - X0; FY := V - Y0;
          C00 := Sample(X0, Y0); C10 := Sample(X1, Y0); C01 := Sample(X0, Y1); C11 := Sample(X1, Y1);
          W00 := (1 - FX) * (1 - FY); W10 := FX * (1 - FY); W01 := (1 - FX) * FY; W11 := FX * FY;
          PA := Ch(C00, 24) * W00 + Ch(C10, 24) * W10 + Ch(C01, 24) * W01 + Ch(C11, 24) * W11;
          if PA < 0.5 then begin
            WritePixel(Wr, X, 0, 0, 0, 0);
            Continue;
          end;
          PR := Ch(C00, 16) * W00 + Ch(C10, 16) * W10 + Ch(C01, 16) * W01 + Ch(C11, 16) * W11;
          PG := Ch(C00, 8) * W00 + Ch(C10, 8) * W10 + Ch(C01, 8) * W01 + Ch(C11, 8) * W11;
          PB := Ch(C00, 0) * W00 + Ch(C10, 0) * W10 + Ch(C01, 0) * W01 + Ch(C11, 0) * W11;
          WritePixel(Wr, X, Min(255, Round(PR * 255 / PA)), Min(255, Round(PG * 255 / PA)), Min(255, Round(PB * 255 / PA)), Round(PA * Opa));
          if Round(PA * Opa) > 0 then NonEmpty := True;
        end;
      end;
      // nothing visible: empty bitmap (fully transparent bitmap is painted black on Windows)
      if NonEmpty then FTransformBmp := IntfImageToBitmap(Img) else FTransformBmp := TBitmap.Create;
    finally
      Img.Free;
    end;
  end;
  if FTransformBmp.Width = 0 then Exit;
  SetCanvasClip(ACanvas, AClipRect);
  DrawCachedBitmap(ACanvas, CB, FTransformBmp);
  {$endif}
end;

procedure THtmlNode.DrawNode(ACanvas: TCanvas; AClipRect: TRect);
var
  Flags: Cardinal;
  TextT: Double;
  ClipText: Boolean;
  R,               // temp rect
  CRect: TRect;    // border box
  S: String;
begin
  CRect := CompSize.ContentRect;
  // nothing is visible (empty clip rect means "no clipping" for canvas, so it must not be set)
  if AClipRect.IsEmpty then Exit;
  R := CRect;
  if FCompStyle.BoxShadow <> '' then InflateRect(R, 100, 100);   // shadow can be outside of node
  if not R.IntersectsWith(AClipRect) then Exit;
  {$ifndef fmx}
  SetCanvasClip(ACanvas, AClipRect, True);
  {$endif}
  PaintBoxShadow(ACanvas);
  PaintBackgroundAndBorder(ACanvas);
  PaintInsetShadow(ACanvas);
  if FElementName = 'svg' then PaintSvgIcon(ACanvas, Self);

  {$ifdef fmx}
  {$else}
  ACanvas.Pen.Style := psClear;
  // Paint Text
  if (Text <> '') and FCompSize.RealContentRect.IntersectsWith(AClipRect) then begin
    ACanvas.Brush.Style := bsClear;
    {$ifdef fpc} ACanvas.Font.BeginUpdate; {$endif}
    AssignFontTo(ACanvas.Font);
    {$ifdef fpc} ACanvas.Font.EndUpdate;{$endif}
    R := FCompSize.RealContentRect;
    if (FCompStyle.Display in [cdtFlex, cdtInlineFlex]) and (FChildCount = 0) then
      R := FlexTextRect(R);    // text in flex container is anonymous flex item
    if FCompStyle.WhiteSpace = cwsNoWrap then
      Flags := DT_LEFT or DT_NOPREFIX or DT_SINGLELINE or DT_END_ELLIPSIS
    else
      Flags := DT_LEFT or DT_NOPREFIX or DT_WORDBREAK;
    case CompStyle.TextAlign of
      ctaCenter: Flags := Flags or DT_CENTER;
      ctaRight: Flags := Flags or DT_RIGHT;
    end;
    // clip is changed only when text can be outside of its box or visible area (R can't be intersected, text is moved
    // when R.Top changes)
    with FCompSize.RealContentRect do
      ClipText := (Left < AClipRect.Left) or (Top < AClipRect.Top) or (Right > AClipRect.Right) or (Bottom > AClipRect.Bottom) or
        (FCachedFont.CachedWidth > R.Right - R.Left) or (FCachedFont.CachedHeight > R.Bottom - R.Top);
    if ClipText then SetCanvasClip(ACanvas, TRect.Intersect(FCompSize.RealContentRect, AClipRect));
    Inc(CSSStats.Texts);
    TextT := CSSTimeMs;
    if (FCompStyle.LineClamp > 0) and (FCompStyle.WhiteSpace = cwsNormal) then begin
      S := ClampedText(R.Right - R.Left);
      DrawText(ACanvas.Handle, PChar(S), Length(S), R, Flags);
    end else if (FCompStyle.WhiteSpace = cwsNoWrap) and (FCachedFont.CachedWidth > R.Right - R.Left) then begin
      S := EllipsisText(R.Right - R.Left);
      DrawText(ACanvas.Handle, PChar(S), Length(S), R, Flags);
    end else
      DrawText(ACanvas.Handle, PChar(Text), Length(Text),  R, Flags);
    CSSStats.TextMs := CSSStats.TextMs + CSSTimeMs - TextT;
    if ClipText then SetCanvasClip(ACanvas, AClipRect);
  end;
  
  if CSS_DEBUG_MODE then begin
    ACanvas.Pen.Style := psDot;
    ACanvas.Pen.Color := clRed;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Rectangle(FCompSize.MarginRect);

    ACanvas.Pen.Color := clBlue;
    ACanvas.Rectangle(FCompSize.ContentRect);

    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Color := clFuchsia;
    ACanvas.Rectangle(CRect.Left, FCompSize.MarginRect.Bottom -  CompSize.BaseLine, CRect.Right,  FCompSize.MarginRect.Bottom - CompSize.BaseLine + 2);
   end;
  {$endif}
end;

procedure THtmlNode.CalculateSize(out AWidth, AHeight, ABaseLine: Integer);
var
  Img: TCSSImageData;
begin
  {$ifdef fpc}
  if (AlignControl <> nil) then begin
    AlignControl.GetPreferredSize(AWidth, AHeight);
    if not AlignControl.AutoSize then AWidth := -1;
    ABaseLine := Round( AHeight / 5);
    Exit;
  end;
 {$endif}

  if FElementName = 'svg' then begin     // intrinsic size of icon: width and height attributes (24 by default)
    AWidth := Round(CSSStrToFloatDef(GetAttribute('width'), 24) * RootNode.FPixelRatio);
    AHeight := Round(CSSStrToFloatDef(GetAttribute('height'), 24) * RootNode.FPixelRatio);
    ABaseLine := AHeight;
    Exit;
  end;
  if FElementName = 'img' then begin     // intrinsic size of image
    AWidth := -1;
    AHeight := -1;
    ABaseLine := 0;
    Img := CSSLoadImage(GetAttribute('src'));
    if Assigned(Img) then begin
      AWidth := Round(Img.Width * RootNode.FPixelRatio);
      AHeight := Round(Img.Height * RootNode.FPixelRatio);
    end;
    Exit;
  end;
  if ((FText = '') and (Element <> 'span')) or (FChildCount > 0) then begin   // container, size is computed from children
    AWidth := -1;
    AHeight := -1;
    ABaseLine := 0;
    Exit;
  end;

  if (FCachedFont.CachedText <> Text) or (FCachedFont.Size.Value <> FCompSize.FontSize) or (FCachedFont.Family <> FCompStyle.Font.Family) or
    (FCachedFont.Weight.FontType <> FCompStyle.Font.Weight.FontType) or (FCachedFont.Style <> FCompStyle.Font.Style) or
    (FCachedFont.Size.LengthType <> cltPx) or (FCachedFont.CachedPixelRatio <> RootNode.FPixelRatio) then begin
    MeasureText(-1, FCachedFont.CachedWidth, FCachedFont.CachedHeight, FCachedFont.CachedBaseLine);
    FCachedFont.CachedMinWidth := MeasureLongestWord;
    FCachedFont.Size.Value := FCompSize.FontSize;
    FCachedFont.Size.LengthType := cltPx;
    FCachedFont.Family := FCompStyle.Font.Family;
    FCachedFont.Weight.FontType := FCompStyle.Font.Weight.FontType;
    FCachedFont.Style := FCompStyle.Font.Style;
    FCachedFont.CachedPixelRatio := RootNode.FPixelRatio;
    FCachedFont.CachedText := Text;
  end;
  AWidth := FCachedFont.CachedWidth;
  AHeight := FCachedFont.CachedHeight;
  ABaseLine := FCachedFont.CachedBaseLine;
end;

(*
  Measure text of node, AMaxWidth = -1 for single line text
*)
procedure THtmlNode.MeasureText(AMaxWidth: Integer; out AWidth, AHeight, ABaseLine: Integer);
var
  Canvas: TCanvas;
  R: TRect;
  {$ifdef fpc}
  TM: TTextMetric;
  {$endif}
begin
  {$ifdef fmx}
  AWidth := 0; AHeight := 0; ABaseLine := 0; // TODO: add fmx support
  {$else}
  if CSSMeasureBitmap = nil then begin
    CSSMeasureBitmap := TBitmap.Create;
    CSSMeasureBitmap.SetSize(1, 1);
  end;
  Canvas := CSSMeasureBitmap.Canvas;
  AssignFontTo(Canvas.Font);
  if AMaxWidth < 0 then begin
    with Canvas.TextExtent(Text) do begin
      AWidth := cx + 1; // to prevent "bold" size bug
      AHeight := cy;
    end;
  end else begin
    R := Rect(0, 0, Max(1, AMaxWidth), 0);
    DrawText(Canvas.Handle, PChar(Text), Length(Text), R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX or DT_LEFT);
    AWidth := Min(R.Width + 1, AMaxWidth);
    AHeight := R.Height;
  end;
  ABaseLine := Round(Canvas.TextHeight('Xg') / 5);
  {$ifdef fpc}
  if GetTextMetrics(Canvas.Handle, TM) and (TM.tmDescent > 0) then ABaseLine := TM.tmDescent;
  {$endif}
  {$endif}
end;

(*
  Width of longest word in text (min-content width of text)
*)
function THtmlNode.MeasureLongestWord: Integer;
var
  Words: TStringArray;
  I: Integer;
begin
  Result := 0;
  {$ifndef fmx}
  if (FText = '') or (CSSMeasureBitmap = nil) then Exit;
  AssignFontTo(CSSMeasureBitmap.Canvas.Font);
  Words := SplitParameters(StringReplace(FText, #10, ' ', [rfReplaceAll]));
  for I := 0 to High(Words) do
    Result := Max(Result, CSSMeasureBitmap.Canvas.TextWidth(Words[I]) + 1);
  {$endif}
end;

(*
  Minimal width of node without overflow (min-content), border box.
  Node and its children must be already measured by layout.
*)
function THtmlNode.MinContentWidth(AAutoMinimum: Boolean): Integer;
var
  N: THtmlNode;
  Sum, Count: Integer;
  Space: Integer;
  FixedWidth: Boolean;
begin
  Space := FCompSize.Padding.Left + FCompSize.Padding.Right + FCompSize.Border.Left + FCompSize.Border.Right;
  FixedWidth := (FCompStyle.Width.LengthType in [cltPx, cltPt, cltEm, cltRem]) or Assigned(FAlignControl);
  if FixedWidth and not AAutoMinimum then
    Exit(FCompSize.ContentWidth);
  Result := 0;
  if FChildCount = 0 then begin
    if FText <> '' then begin
      if FCompStyle.WhiteSpace = cwsNoWrap then Result := FCachedFont.CachedWidth
        else Result := FCachedFont.CachedMinWidth;
    end;
  end else begin
    Sum := 0;
    Count := 0;
    N := FFirstChild;
    while Assigned(N) do begin
      if (N.FCompStyle.Display <> cdtNone) and not (N.FCompStyle.Position in [cpAbsolute, cpFixed]) then begin
        if (FCompStyle.Display in [cdtFlex, cdtInlineFlex]) and (FCompStyle.FlexDirection in [cfdRow, cfdRowReverse]) and
          (FCompStyle.FlexWrap = cfwNoWrap) then
          Inc(Sum, N.MinContentWidth + N.FCompSize.Margin.Left + N.FCompSize.Margin.Right)
        else
          Result := Max(Result, N.MinContentWidth + N.FCompSize.Margin.Left + N.FCompSize.Margin.Right);
        Inc(Count);
      end;
      N := N.FNextSibling;
    end;
    if Sum > 0 then begin
      if Count > 1 then Inc(Sum, (Count - 1) * Max(0, CalcLength(FCompStyle.ColumnGap, -1)));
      Result := Max(Result, Sum);
    end;
  end;
  Inc(Result, Space);
  // automatic minimum of flex item is never bigger than specified width
  if AAutoMinimum and FixedWidth then Result := Min(Result, FCompSize.ContentWidth);
end;

(*
  Pixel height (em) of default font, measured once
*)
function CSSDefaultFontHeight: Integer;
var
  H0, H: Integer;
begin
  {$ifndef fmx}
  if CSSDefaultFontPx > 0 then Exit(CSSDefaultFontPx);
  if CSSMeasureBitmap = nil then begin
    CSSMeasureBitmap := TBitmap.Create;
    CSSMeasureBitmap.SetSize(1, 1);
  end;
  with CSSMeasureBitmap.Canvas do begin
    Font.Name := 'default';
    Font.Style := [];
    Font.Size := 0;
    H0 := TextHeight('Xg');
    CSSDefaultFontPx := 13;
    for H := 6 to 40 do begin
      Font.Height := -H;
      if TextHeight('Xg') >= H0 then begin
        CSSDefaultFontPx := H;
        Break;
      end;
    end;
    Font.Size := 0;
  end;
  {$endif}
  Result := CSSDefaultFontPx;
end;

(*
  Setup canvas font based on computed style
*)
procedure THtmlNode.AssignFontTo(AFont: TFont);
var
  St: TFontStyles;
begin
  St := [];
  if FCompStyle.Font.Weight.FontType = cfwBold then Include(St, {$ifdef delphi}TFontStyle.{$endif}fsBold);
  if FCompStyle.Font.Style in [cfsItalic, cfsOblique] then Include(St, {$ifdef delphi}TFontStyle.{$endif}fsItalic);
  case FCompStyle.Font.TextDecoration of
    ctdUnderline: Include(St, {$ifdef delphi}TFontStyle.{$endif}fsUnderline);
    ctdLineThrough: Include(St, {$ifdef delphi}TFontStyle.{$endif}fsStrikeOut);
  end;
  {$ifndef fmx}
  AFont.Name := CSSResolveFontFamily(FCompStyle.Font.Family);
  if FCompSize.FontSize > 0 then
    AFont.Height := -Round(FCompSize.FontSize * RootNode.FPixelRatio)
  else if Abs(RootNode.FRenderScale - 1) > 0.01 then
    AFont.Height := -Round(CSSDefaultFontHeight * RootNode.FRenderScale)   // default font in higher resolution
  else
    AFont.Size := 0;
  AFont.Style := St;
  AFont.Color := EffectiveColor(FCompStyle.Color);
  {$endif}
end;

(*
  Position of text in flex container (text is aligned like one flex item)
*)
function THtmlNode.FlexTextRect(const AContent: TRect): TRect;
var
  TW, TH, TB, FreeW, FreeH, X, Y: Integer;
  MainAlign: TCSSJustifyContent;
  CrossAlign: TCSSAlignItems;
  function MainOffset(AFree: Integer): Integer;
  begin
    case MainAlign of
      cjcFlexEnd: Result := AFree;
      cjcCenter, cjcSpaceAround, cjcSpaceEvenly: Result := AFree div 2;
      else Result := 0;
    end;
  end;
  function CrossOffset(AFree: Integer): Integer;
  begin
    case CrossAlign of
      caiFlexEnd: Result := AFree;
      caiCenter: Result := AFree div 2;
      else Result := 0;
    end;
  end;
begin
  Result := AContent;
  if FCompStyle.WhiteSpace = cwsNoWrap then MeasureText(-1, TW, TH, TB)
    else MeasureText(Max(1, AContent.Width), TW, TH, TB);
  TW := Min(TW, AContent.Width);
  FreeW := Max(0, AContent.Width - TW);
  FreeH := Max(0, AContent.Height - TH);
  MainAlign := FCompStyle.JustifyContent;
  CrossAlign := FCompStyle.AlignItems;
  if FCompStyle.FlexDirection in [cfdRow, cfdRowReverse] then begin
    X := MainOffset(FreeW);
    Y := CrossOffset(FreeH);
    if FCompStyle.FlexDirection = cfdRowReverse then X := FreeW - X;
  end else begin
    Y := MainOffset(FreeH);
    X := CrossOffset(FreeW);
    if CrossAlign = caiStretch then TW := AContent.Width;
    if FCompStyle.FlexDirection = cfdColumnReverse then Y := FreeH - Y;
  end;
  Result := Rect(AContent.Left + X, AContent.Top + Y, AContent.Left + X + TW, AContent.Top + Y + TH);
end;

function THtmlNode.BorderColor(ASide: TCSSSide): TColor;
begin
  if FCompStyle.Border[ASide].Color.ColorType = cctNormal then
    Result := FCompStyle.Border[ASide].Color.Value
  else
    Result := FCompStyle.Color.Value;   // currentcolor
end;

(*
  Calculate corner radius in px, overlapping radii are reduced
  https://www.w3.org/TR/css-backgrounds-3/#corner-overlap
*)
procedure THtmlNode.CalcRadius(AWidth, AHeight: Integer; out ATopLeft, ATopRight, ABottomRight, ABottomLeft: TPoint);
  function RadiusPoint(const ARadius: TCSSBorderRadius): TPoint;
  begin
    Result.x := Max(0, CalcLength(ARadius.Width, AWidth));
    Result.y := Max(0, CalcLength(ARadius.Height, AHeight));
    if (Result.x = MaxInt) or (Result.y = MaxInt) or (Result.x = 0) or (Result.y = 0) then Result := Point(0, 0);
  end;
  procedure Reduce(var F: Double; ASide: Integer; R1, R2: Integer);
  begin
    if (R1 + R2 > 0) and (ASide / (R1 + R2) < F) then F := ASide / (R1 + R2);
  end;
  function ScalePoint(const P: TPoint; F: Double): TPoint;
  begin
    Result := Point(Trunc(P.x * F), Trunc(P.y * F));
  end;
  // corner touching rounded corner of clipping parent (overflow: hidden) gets its inner radius
  procedure ClipCorner(var P: TPoint; AIndex, DX, DY: Integer);
  begin
    with CSSPaintClip do
      if (RX[AIndex] > 0) and (DX >= 0) and (DY >= 0) and (DX <= 1) and (DY <= 1) then begin
        P.x := Max(P.x, RX[AIndex] - DX);
        P.y := Max(P.y, RY[AIndex] - DY);
      end;
  end;
var
  F: Double;
begin
  ATopLeft := RadiusPoint(FCompStyle.RadiusTopLeft);
  ATopRight := RadiusPoint(FCompStyle.RadiusTopRight);
  ABottomRight := RadiusPoint(FCompStyle.RadiusBottomRight);
  ABottomLeft := RadiusPoint(FCompStyle.RadiusBottomLeft);
  if CSSPaintClip.Active then
    with FCompSize.ContentRect, CSSPaintClip do begin
      ClipCorner(ATopLeft, 0, Left - Box.Left, Top - Box.Top);
      ClipCorner(ATopRight, 1, Box.Right - Right, Top - Box.Top);
      ClipCorner(ABottomRight, 2, Box.Right - Right, Box.Bottom - Bottom);
      ClipCorner(ABottomLeft, 3, Left - Box.Left, Box.Bottom - Bottom);
    end;
  F := 1;
  Reduce(F, AWidth, ATopLeft.x, ATopRight.x);
  Reduce(F, AWidth, ABottomLeft.x, ABottomRight.x);
  Reduce(F, AHeight, ATopLeft.y, ABottomLeft.y);
  Reduce(F, AHeight, ATopRight.y, ABottomRight.y);
  if F < 1 then begin
    ATopLeft := ScalePoint(ATopLeft, F);
    ATopRight := ScalePoint(ATopRight, F);
    ABottomRight := ScalePoint(ABottomRight, F);
    ABottomLeft := ScalePoint(ABottomLeft, F);
  end;
end;

constructor THtmlNode.Create(AInlineStyle: String = '');
var
  I: Integer;
begin
  FCompStyle := TCSSItem.Create;
  FCompSize := THtmlSize.Create;
  FClassList := TCSSClassList.Create;
  FCachedFont.Size.Value := -1;
  RootNode := Self;
  FPixelRatio := 1;
  FPaintScale := 1;
  FRenderScale := 1;
  FViewportWidth := -1;
  FElementName := 'div';    // default
  FFreeMe := True;
  FText := '';
  FInlineStyle := AInlineStyle;
  FCompStyle.Parse(FInlineStyle);
end;

destructor THtmlNode.Destroy;
var
  I: Integer;
begin
  StopAnimation;
  Clear;
  Detach;
  if FOwnsData then FData.Free;
  for I := 0 to High(FBgCache) do FBgCache[I].Bmp.Free;
  FTransformBmp.Free;
  FAttributes.Free;
  FClassList.Free;
  FCompSize.Free;
  FCompStyle.Free;
  inherited Destroy;
end;

procedure THtmlNode.Assign(Source: TPersistent);
var
  Src: THtmlNode;
begin
  if Source is THtmlNode then begin
    Src := THtmlNode(Source);
    Element := Src.Element;
    Id := Src.Id;
    InlineStyle := Src.InlineStyle;
    AlignControl := Src.AlignControl;
  end else
    inherited Assign(Source);
end;

function THtmlNode.ApplyStyle: THtmlNode;
begin
  Result := Self;
  ApplyStyleForNode(Self);
end;

(*
  Styles of node (and of its subtree if ADeep, eg. group-hover) are applied again after change of state
  (hover, active, focus). Returns True when layout must be computed again. Otherwise only painted values
  are updated (inherited values, transforms) and ADirty is area to repaint, so hover over a big tree
  doesn't need styles and layout of the whole tree.
*)
function THtmlNode.RestyleState(ADeep: Boolean; var ADirty: TRect): Boolean;
var
  NeedLayout: Boolean;
  Restyled: array of THtmlNode;     // nodes which look different (new area is added after transforms are computed)
  I: Integer;
  procedure AddDirty(const R: TRect);
  begin
    if R.IsEmpty then Exit;
    if ADirty.IsEmpty then ADirty := R else ADirty := TRect.Union(ADirty, R);
  end;
  procedure Walk(N: THtmlNode; Deep: Boolean);
  var
    Old, OldPaint: String;
    C: THtmlNode;
    OldArea: TRect;
    Lay: Boolean;
  begin
    Old := N.FCompStyle.LayoutKey;
    OldPaint := N.FCompStyle.PaintKey;
    OldArea := N.PaintedRect;
    N.ApplyStyleForNode(N);
    N.ResolveInheritedStyle;
    Lay := N.FCompStyle.LayoutKey <> Old;
    if Lay then NeedLayout := True;
    // area is painted again only when node looks different (state of node can change without change of style)
    if Lay or (N.FCompStyle.PaintKey <> OldPaint) then begin
      AddDirty(OldArea);
      SetLength(Restyled, Length(Restyled) + 1);
      Restyled[High(Restyled)] := N;
    end;
    if Deep then begin
      C := N.FFirstChild;
      while Assigned(C) do begin
        Walk(C, True);
        C := C.FNextSibling;
      end;
    end;
  end;
  procedure Refresh(N: THtmlNode; AResolve: Boolean);
  var
    C: THtmlNode;
  begin
    if AResolve then N.ResolveInheritedStyle;      // eg. color inherited from hovered parent
    N.ComputeTransform;
    C := N.FFirstChild;
    while Assigned(C) do begin
      Refresh(C, True);
      C := C.FNextSibling;
    end;
  end;
begin
  NeedLayout := False;
  Restyled := nil;
  Walk(Self, ADeep);
  if not NeedLayout then begin
    Refresh(Self, False);
    for I := 0 to High(Restyled) do AddDirty(Restyled[I].PaintedRect);    // new area (eg. translate on hover)
  end;
  Result := NeedLayout;
end;

(*
  Apply styles to this node and all descendants
*)
function THtmlNode.ApplyStyles: THtmlNode;
begin
  Result := Self;
  ApplySubtree(Self);
  if Assigned(RootNode) then RootNode.NoteChanged(Self);
end;

(*
  Apply style to selected node, slow parsing text each time.
*)
procedure THtmlNode.ApplyStyleForNode(ANode: THtmlNode);
var
  Rules: TList;
  sh: TCSSStyleSheet;
  Item: TCSSItem;
  I: Integer;
  Decl: String;
  Spec, Order: Integer;
  TempRules: array of TCSSItem;
  OldColors: TCSSColorChannels;
  OldOpacity: Single;
begin
  if ANode.RootNode = Nil then exit;
  Inc(CSSPaintGeneration);
  sh := ANode.RootNode.StyleSheet;
  GetColorChannels(ANode.FCompStyle, OldColors);       // shown values (can be values of running transition)
  OldOpacity := ANode.FCompStyle.Opacity;
  ANode.FCompStyle.Reset;
  ApplyElementDefaults(ANode);
  Rules := TList.Create;
  TempRules := nil;
  try
    // collect matching rules from stylesheet
    if Assigned(sh) then
      for I := 0 to sh.Count - 1 do begin
        Item := sh.Items[I];
        Item.CompileSelector;
        if Item.SelectorValid and ANode.Matches(Item.Selector) then Rules.Add(Item);
      end;
    // utility classes (rules are created temporary)
    if Assigned(CSSUtilityResolver) then
      for I := 0 to ANode.ClassList.Count - 1 do
        if ANode.UtilityClass(ANode.ClassList.Item[I], Decl, Spec, Order) and (Copy(Decl, 1, 1) <> '>') then begin
          Item := TCSSItem.Create;
          Item.Attributes := Decl;
          Item.Specificity := Spec;
          Item.Weight := CSS_UTILITY_ORDER_BASE + Order;
          SetLength(TempRules, Length(TempRules) + 1);
          TempRules[High(TempRules)] := Item;
          Rules.Add(Item);
        end;
    // utilities of parent for its children ("> * + *" in Tailwind): space-x-*, space-y-*, divide-*
    // declarations start with ">" and are applied to every child except the first one
    if Assigned(CSSUtilityResolver) and Assigned(ANode.ParentNode) and ANode.HasPrevElementSibling and
      ((Pos('space-', ANode.ParentNode.ClassList.Name) > 0) or (Pos('divide-', ANode.ParentNode.ClassList.Name) > 0)) then
      for I := 0 to ANode.ParentNode.ClassList.Count - 1 do
        if ANode.ParentNode.UtilityClass(ANode.ParentNode.ClassList.Item[I], Decl, Spec, Order) and (Copy(Decl, 1, 1) = '>') then begin
          Item := TCSSItem.Create;
          Item.Attributes := Copy(Decl, 2, MaxInt);
          Item.Specificity := Spec + 10;
          Item.Weight := CSS_UTILITY_ORDER_BASE + Order;
          SetLength(TempRules, Length(TempRules) + 1);
          TempRules[High(TempRules)] := Item;
          Rules.Add(Item);
        end;
    // cascade order: specificity, then order of definition
    Rules.Sort(@CompareCSSRules);
    for I := 0 to Rules.Count - 1 do
      ANode.FCompStyle.Parse(TCSSItem(Rules[I]).Attributes);
  finally
    Rules.Free;
    for I := 0 to High(TempRules) do TempRules[I].Free;
  end;
  if ANode.InlineStyle <> '' then  ANode.FCompStyle.Parse(ANode.InlineStyle);
  if (ANode.Hovered) and (ANode.HoverStyle <> '') then
      ANode.FCompStyle.Parse(ANode.HoverStyle);
  // <img src="..."> is painted as background image (rounded corners, shadows work)
  if (ANode.FElementName = 'img') and (ANode.GetAttribute('src') <> '') and (ANode.FCompStyle.Background.Image = '') then
    with ANode.FCompStyle do begin
      Background.Image := 'url("' + ANode.GetAttribute('src') + '")';
      Background.RepeatMode := 'no-repeat';
      if ObjectPosition <> '' then Background.Position := ObjectPosition else Background.Position := 'center';
      if (ObjectFit = 'contain') or (ObjectFit = 'scale-down') then Background.Size := 'contain'
      else if ObjectFit = 'cover' then Background.Size := 'cover'
      else if ObjectFit = 'none' then Background.Size := 'auto'
      else Background.Size := '100% 100%';
    end;
  ANode.UpdateTransitions(OldColors, OldOpacity, ANode.FTransform);
end;

(*
  Default styles of html elements (like browser stylesheet, Tailwind preflight resets most of them)
*)
procedure THtmlNode.ApplyElementDefaults(ANode: THtmlNode);
const
  INLINE_ELEMENTS: array[0..24] of String = ('span', 'a', 'b', 'strong', 'i', 'em', 'u', 's', 'del', 'small', 'label',
    'code', 'kbd', 'mark', 'sub', 'sup', 'abbr', 'time', 'img', 'svg', 'button', 'input', 'cite', 'q', '#text');
  HEADING_SIZES: array[1..6] of String = ('2em', '1.5em', '1.17em', '1em', '0.83em', '0.67em');
var
  E: String;
  I: Integer;
  cs: TCSSItem;
begin
  E := ANode.FElementName;
  cs := ANode.FCompStyle;
  for I := 0 to High(INLINE_ELEMENTS) do
    if INLINE_ELEMENTS[I] = E then begin
      cs.Display := cdtInline;
      Break;
    end;
  if (E = 'b') or (E = 'strong') then cs.AddParsedProperty('font-weight', 'bold')
  else if (E = 'i') or (E = 'em') or (E = 'cite') then cs.AddParsedProperty('font-style', 'italic')
  else if E = 'u' then cs.AddParsedProperty('text-decoration', 'underline')
  else if (E = 's') or (E = 'del') then cs.AddParsedProperty('text-decoration', 'line-through')
  else if (E = 'code') or (E = 'kbd') or (E = 'pre') then cs.AddParsedProperty('font-family', 'monospace')
  else if E = 'br' then cs.Height := CSSToLength('0')     // line break: empty block
  else if E = 'hr' then cs.AddProperty('border-top', '1px solid #e5e7eb')
  else if CSSUtilityResolver = nil then begin   // without Tailwind like utilities (preflight resets these)
    if (Length(E) = 2) and (E[1] = 'h') and (E[2] in ['1'..'6']) then begin
      cs.AddParsedProperty('font-weight', 'bold');
      cs.AddParsedProperty('font-size', HEADING_SIZES[Ord(E[2]) - Ord('0')]);
      cs.AddProperty('margin', '0.67em 0');
    end else
    if E = 'p' then cs.AddProperty('margin', '1em 0')
    else if E = 'a' then begin
      cs.AddParsedProperty('color', '#0000ee');
      cs.AddParsedProperty('text-decoration', 'underline');
      cs.Cursor := crHandPoint;
    end;
  end;
end;

(*
  Check variants of utility class (eg. "hover:md:bg-red-500") and resolve it to CSS declarations
*)
function THtmlNode.UtilityClass(const AClassName: String; out ADeclarations: String; out ASpecificity, AOrder: Integer): Boolean;
const
  BREAKPOINTS: array[0..4] of record Name: String; Width: Integer; end = (
    (Name: 'sm'; Width: 640), (Name: 'md'; Width: 768), (Name: 'lg'; Width: 1024), (Name: 'xl'; Width: 1280), (Name: '2xl'; Width: 1536));
var
  Name, Variant: String;
  I, P, VW, BpIndex, Depth: Integer;
begin
  Result := False;
  ADeclarations := '';
  ASpecificity := 100;
  AOrder := 0;
  BpIndex := -1;
  Name := AClassName;
  repeat
    // variant separator ":" outside of arbitrary value [...]
    P := 0;
    Depth := 0;
    for I := 1 to Length(Name) do begin
      if Name[I] = '[' then Inc(Depth)
      else if Name[I] = ']' then Dec(Depth)
      else if (Name[I] = ':') and (Depth = 0) then begin
        P := I;
        Break;
      end;
    end;
    if P = 0 then Break;
    Variant := Copy(Name, 1, P - 1);
    Name := Copy(Name, P + 1, MaxInt);
    if Variant = 'hover' then begin
      if not FHovered then Exit;
    end else
    if Variant = 'active' then begin
      if not FActive then Exit;
    end else
    if Variant = 'focus' then begin
      if not FFocused then Exit;
    end else
    if Variant = 'focus-within' then begin
      if not HasFocusWithin then Exit;
    end else
    if Variant = 'first' then begin
      if Assigned(FPrevSibling) then Exit;
    end else
    if Variant = 'last' then begin
      if Assigned(FNextSibling) then Exit;
    end else
    if Variant = 'odd' then begin
      if Odd(SiblingIndex) then Exit;    // 1st, 3rd ... (index 0, 2 ...)
    end else
    if Variant = 'even' then begin
      if not Odd(SiblingIndex) then Exit;
    end else
    if Variant = 'group-hover' then begin
      if not HasHoveredAncestorWithClass('group') then Exit;
    end else
    if Variant = 'dark' then begin
      if not CSSDarkMode then Exit;
    end else begin
      // responsive variants (mobile first, compared with width of root node)
      I := High(BREAKPOINTS);
      while (I >= 0) and (BREAKPOINTS[I].Name <> Variant) do Dec(I);
      if I < 0 then Exit;     // unknown variant
      VW := RootNode.FViewportWidth;
      if (VW < 0) or (VW < BREAKPOINTS[I].Width) then Exit;
      BpIndex := Max(BpIndex, I);
      Continue;
    end;
    Inc(ASpecificity, 100);   // pseudo class
  until False;
  if (Name <> '') and (Name[1] = '!') then System.Delete(Name, 1, 1);  // important modifier is ignored
  if Name = '' then Exit;
  Result := CSSResolveUtility(Name, ADeclarations, AOrder);
  if Result and (BpIndex >= 0) then Inc(AOrder, (BpIndex + 1) * CSS_UTILITY_BREAKPOINT_ORDER);  // responsive utilities are after base utilities
end;

function THtmlNode.SiblingIndex: Integer;
var
  N: THtmlNode;
begin
  Result := 0;
  N := FPrevSibling;
  while Assigned(N) do begin
    Inc(Result);
    N := N.FPrevSibling;
  end;
end;

function THtmlNode.HasHoveredAncestorWithClass(const AClass: String): Boolean;
var
  N: THtmlNode;
begin
  N := ParentNode;
  while Assigned(N) do begin
    if N.FHovered and N.ClassList.Contains(AClass) then Exit(True);
    N := N.ParentNode;
  end;
  Result := False;
end;

function THtmlNode.MatchesCompound(const ACompound: TCSSCompoundSelector): Boolean;
var
  I: Integer;
  P: String;
begin
  Result := False;
  if FElementName = '#text' then Exit;   // anonymous text node (html parser) has only inherited styles
  if (ACompound.Element <> '') and (ACompound.Element <> CSS_UNIVERSAL_SELECTOR) and not SameText(ACompound.Element, FElementName) then Exit;
  if (ACompound.Id <> '') and (ACompound.Id <> FId) then Exit;
  for I := 0 to High(ACompound.Classes) do
    if not FClassList.Contains(ACompound.Classes[I]) then Exit;
  for I := 0 to High(ACompound.Pseudos) do begin
    P := ACompound.Pseudos[I];
    if P = 'hover' then begin
      if not FHovered then Exit;
    end else
    if P = 'active' then begin
      if not FActive then Exit;
    end else
    if P = 'focus' then begin
      if not FFocused then Exit;
    end else
    if P = 'focus-within' then begin
      if not HasFocusWithin then Exit;
    end else
    if P = 'first-child' then begin
      if Assigned(FPrevSibling) then Exit;
    end else
    if P = 'last-child' then begin
      if Assigned(FNextSibling) then Exit;
    end else
    if P = 'only-child' then begin
      if Assigned(FPrevSibling) or Assigned(FNextSibling) then Exit;
    end else
      Exit;   // not supported pseudo class
  end;
  Result := True;
end;

(*
  Match selector from right to left
*)
function THtmlNode.Matches(const ASelector: TCSSCompoundSelectors): Boolean;
  function MatchFrom(ANode: THtmlNode; AIndex: Integer): Boolean;
  var
    P: THtmlNode;
  begin
    Result := ANode.MatchesCompound(ASelector[AIndex]);
    if (not Result) or (AIndex = 0) then Exit;
    if ASelector[AIndex].Combinator = ccChild then
      Result := Assigned(ANode.ParentNode) and MatchFrom(ANode.ParentNode, AIndex - 1)
    else begin   // descendant
      P := ANode.ParentNode;
      while Assigned(P) do begin
        if MatchFrom(P, AIndex - 1) then Exit(True);
        P := P.ParentNode;
      end;
      Result := False;
    end;
  end;
begin
  Result := (Length(ASelector) > 0) and MatchFrom(Self, High(ASelector));
end;

function THtmlNode.Matches(const ASelector: String): Boolean;
var
  Spec: Integer;
begin
  Result := Matches(ParseSelector(ASelector, Spec));
end;

procedure THtmlNode.PaintTo(ACanvas: TCanvas);
begin
  UpdateStickyOffsets;
  // clip rect must not overflow when canvas adds offset of control (LPtoDP), so MaxInt can't be used
  PaintNodeTree(ACanvas, Rect(0, 0, $100000, $100000));
end;

procedure THtmlNode.PaintTo(ACanvas: TCanvas; const AClipRect: TRect);
begin
  UpdateStickyOffsets;
  PaintNodeTree(ACanvas, AClipRect);
end;

function THtmlNode.SetAlignControl(AValue: TControl): THtmlNode;
begin
  Result := Self;
  AlignControl := AValue;
end;

(*
  Space separated
*)
function THtmlNode.SetClass(AValues: String): THtmlNode;
begin
  Result := Self;
  FClassList.Name := AValues;
  ApplyStyleForNode(Self);
  Changed;
end;


(*
  Align all nodes on same line based on base line and return max bottom
  https://developer.mozilla.org/en-US/docs/Web/CSS/vertical-align
  TODO: Add support for various vertical-align
*)
function THtmlNode.LayoutDoVerticalAlign(AList: TList; ClearList: Boolean = True): Integer;
var
  Dif,
  mI: Integer;
  Item: THtmlNode;
  MinMargin,
  MaxBaseLine: Integer;
begin
  MaxBaseLine := 0;
  Result := 0;
  MinMargin := MaxInt;
  for mI := 0 to AList.Count-1 do begin
    Item := THtmlNode(AList.Items[mI]);
    if Item.CompStyle.Position <> cpAbsolute then  begin
      MaxBaseLine := Max(MaxBaseLine, Item.FCompSize.MarginRect.Bottom -  Item.FCompSize.BaseLine - Item.FCompSize.Position.Top);
      MinMargin := Math.Min(MinMargin, Item.CompSize.MarginRect.Top);
    end;
  end;
  if MinMargin = MaxInt then MinMargin := 0;;
  for mI := 0 to AList.Count-1 do begin                 // realign top and bottom of all controls
    Item := THtmlNode(AList.Items[mI]);

    if Item.CompStyle.Position = cpAbsolute then Continue;
    if Item.FCompSize.MarginRect.Bottom - Item.FCompSize.BaseLine - Item.FCompSize.Position.Top < MaxBaseLine then begin
      Dif := MaxBaseLine - (Item.FCompSize.MarginRect.Bottom - Item.FCompSize.BaseLine - Item.FCompSize.Position.Top);
      Inc(Item.FCompSize.ContentRect.Top, Dif);
      Inc(Item.FCompSize.ContentRect.Bottom, Dif);
      Inc(Item.FCompSize.MarginRect.Top, Dif);
      Inc(Item.FCompSize.MarginRect.Bottom, Dif);
    end;
    Result := Math.Max(Result, Item.CompSize.MarginRect.Bottom - MinMargin);
  end;
  if ClearList then AList.Clear;
end;

(*
  Convert CSS length to pixels for this node (em is relative to node font size)
*)
function THtmlNode.CalcLength(const AValue: TCSSLength; AParentLength: Integer): Integer;
var
  FontSize: Single;
begin
  FontSize := FCompSize.FontSize;
  if FontSize <= 0 then FontSize := CSSRootFontSize;
  Result := CalcCSSLength(AValue, AParentLength, FontSize, RootNode.FPixelRatio);
end;

function THtmlNode.BorderWidth(ASide: TCSSSide): Integer;
begin
  if FCompStyle.Border[ASide].Style in [cbsUndefined, cbsNone, cbsHidden] then
    Result := 0
  else
    Result := Max(0, CalcLength(FCompStyle.Border[ASide].Width, 0));
end;

(*
  Resolve inherited properties (color, font, text-align...) from parent node and compute font size in px
  Only properties not specified by node style are inherited, so it can be called repeatedly.
*)
procedure THtmlNode.ResolveInheritedStyle;
var
  cs, ps: TCSSItem;
  ParentFontSize: Single;
begin
  cs := FCompStyle;
  if Assigned(ParentNode) then ps := ParentNode.FCompStyle else ps := Nil;
  FColorAnimated := False;          // next frame of transition sets it again
  if not (cipColor in cs.Specified) or (cs.Color.ColorType in [cctUndefined, cctCurrentColor]) then begin
    if Assigned(ps) then cs.Color := ps.Color
    else begin
      cs.Color.Value := {$ifdef fmx}TColorRec.Black{$else}clBlack{$endif};
      cs.Color.ColorType := cctNormal;
      cs.Color.Alpha := 255;
    end;
  end;
  if not (cipFontFamily in cs.Specified) then
    if Assigned(ps) then cs.Font.Family := ps.Font.Family else cs.Font.Family := '';
  if not (cipFontStyle in cs.Specified) then
    if Assigned(ps) then cs.Font.Style := ps.Font.Style else cs.Font.Style := cfsNormal;
  if not (cipFontWeight in cs.Specified) then begin
    if Assigned(ps) then cs.Font.Weight := ps.Font.Weight
    else begin
      cs.Font.Weight.FontType := cfwNormal;
      cs.Font.Weight.Value := [];
    end;
  end;
  if not (cipTextDecoration in cs.Specified) then
    if Assigned(ps) then cs.Font.TextDecoration := ps.Font.TextDecoration else cs.Font.TextDecoration := ctdNone;
  if not (cipTextAlign in cs.Specified) then
    if Assigned(ps) then cs.TextAlign := ps.TextAlign else cs.TextAlign := ctaUndefined;
  if not (cipWhiteSpace in cs.Specified) then
    if Assigned(ps) then cs.WhiteSpace := ps.WhiteSpace else cs.WhiteSpace := cwsNormal;

  // font size in px; 0 = default system font
  if Assigned(ParentNode) then ParentFontSize := ParentNode.FCompSize.FontSize else ParentFontSize := 0;
  if (cipFontSize in cs.Specified) and (cs.Font.Size.LengthType <> cltUndefined) then begin
    if ParentFontSize <= 0 then ParentFontSize := CSSRootFontSize;
    case cs.Font.Size.LengthType of
      cltPx: FCompSize.FontSize := cs.Font.Size.Value;
      cltPt: FCompSize.FontSize := cs.Font.Size.Value * 96 / 72;
      cltEm: FCompSize.FontSize := cs.Font.Size.Value * ParentFontSize;
      cltPercentage: FCompSize.FontSize := cs.Font.Size.Value / 100 * ParentFontSize;
      cltRem: FCompSize.FontSize := cs.Font.Size.Value * CSSRootFontSize;
      else FCompSize.FontSize := ParentFontSize;
    end;
  end else
    FCompSize.FontSize := ParentFontSize;
end;

(*
  Calculate size of node
  InFlex - node is flex item (size is calculated by flex layout)
  AForceWidth, AForceHeight - border box size set by flex layout (-1 = not set)
*)
var
  CSSLayoutPass: Cardinal = 0;     // incremented by LayoutTo, cached sizes are valid only in one pass
  CSSLayoutRecompute: THtmlNode;   // node laid out again without cache (children are arranged for last request)

function HasPercentSide(const ASides: array of TCSSLength): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASides) do
    if ASides[I].LengthType = cltPercentage then Exit(True);
  Result := False;
end;

function SameLayoutKey(const A, B: TCSSLayoutKey): Boolean; inline;
begin
  Result := (A.PW = B.PW) and (A.PH = B.PH) and (A.FW = B.FW) and (A.FH = B.FH) and (A.InFlex = B.InFlex);
end;

procedure THtmlNode.LayoutGetNodeSize(ANode: THtmlNode; ParentWidth, ParentHeight: Integer; InFlex: Boolean; AForceWidth: Integer; AForceHeight: Integer);
var
  Key: TCSSLayoutKey;
  Cached: Boolean;
  I: Integer;
  childWidth,
  childHeight,
  cW, cH, cB: Integer;
  HorzSpace, VertSpace: Integer;   // padding + border
  TextW, TextH, AvailW, PW, PH, LineH: Integer;
  R: TRect;
  cs: TCSSItem;
  function AutoToZero(AValue: Integer): Integer; inline;
  begin
    if AValue = MaxInt then Result := 0 else Result := AValue;
  end;
  // returns -1 if size can't be computed
  function SpecifiedSize(const ALength: TCSSLength; AParent, ASpace: Integer): Integer;
  begin
    Result := -1;
    case ALength.LengthType of
      cltPercentage: if AParent >= 0 then Result := Round((AParent/100) * ALength.Value);
      cltPx, cltPt, cltEm, cltRem: Result := ANode.CalcLength(ALength, AParent);
      else Exit;
    end;
    if (Result >= 0) and (cs.BoxSizing = cbxBorderBox) then Result := Max(0, Result - ASpace);
  end;
  // apply min-*, max-* constraints
  function Constrain(AValue: Integer; const AMin, AMax: TCSSLength; AParent, ASpace: Integer): Integer;
  var
    L: Integer;
  begin
    Result := AValue;
    if Result < 0 then Exit;
    L := SpecifiedSize(AMax, AParent, ASpace);
    if (L >= 0) and (Result > L) then Result := L;
    L := SpecifiedSize(AMin, AParent, ASpace);
    if (L >= 0) and (Result < L) then Result := L;
  end;
begin
  cs := ANode.FCompStyle;
  // cached size for the same input in this pass: children keep their layout, they are arranged again at the end
  // of LayoutTo when the last request differs (FixLayout), so the result is the same as without cache
  Key.PW := ParentWidth; Key.PH := ParentHeight; Key.FW := AForceWidth; Key.FH := AForceHeight; Key.InFlex := InFlex;
  // parent size is used only by percentages, auto width of block and wrapped text (children get size of this
  // node), so it is not part of key when node doesn't use it
  if not ((cs.Height.LengthType = cltPercentage) or (cs.MinHeight.LengthType = cltPercentage) or
    (cs.MaxHeight.LengthType = cltPercentage) or (cs.Top.LengthType = cltPercentage) or
    (cs.Bottom.LengthType = cltPercentage)) then Key.PH := -2;
  if InFlex and not ((cs.Width.LengthType = cltPercentage) or (cs.MinWidth.LengthType = cltPercentage) or
    (cs.MaxWidth.LengthType = cltPercentage) or (cs.Left.LengthType = cltPercentage) or
    (cs.Right.LengthType = cltPercentage) or HasPercentSide(cs.Margin) or HasPercentSide(cs.Padding) or
    ((ANode.FText <> '') and (ANode.FChildCount = 0) and (AForceWidth < 0))) then Key.PW := -2;
  Cached := not ANode.FLayoutRoot and not (cs.Position in [cpAbsolute, cpFixed]) and (ANode <> CSSLayoutRecompute);
  if Cached then begin
    if ANode.FLayPass <> CSSLayoutPass then begin
      ANode.FLayPass := CSSLayoutPass;
      ANode.FLayCount := 0;
    end else
      for I := 0 to ANode.FLayCount - 1 do
        if SameLayoutKey(ANode.FLayResults[I].Key, Key) then
          with ANode.FLayResults[I] do begin
            ANode.FCompSize.Margin := Margin;
            ANode.FCompSize.Padding := Padding;
            ANode.FCompSize.Border := Border;
            ANode.FCompSize.Position := Position;
            ANode.FCompSize.BaseLine := BaseLine;
            ANode.FCompSize.ContentWidth := ContentWidth;
            ANode.FCompSize.ContentHeight := ContentHeight;
            ANode.FLayWanted := Key;
            ANode.FLayWantedPW := ParentWidth;
            ANode.FLayWantedPH := ParentHeight;
            Exit;
          end;
  end;
  ANode.ResolveInheritedStyle;

  // insets of absolute node are relative to padding box of parent
  PW := ParentWidth;
  PH := ParentHeight;
  if (cs.Position in [cpAbsolute, cpFixed]) and Assigned(ANode.ParentNode) then begin
    if PW >= 0 then Inc(PW, ANode.ParentNode.FCompSize.Padding.Left + ANode.ParentNode.FCompSize.Padding.Right);
    if PH >= 0 then Inc(PH, ANode.ParentNode.FCompSize.Padding.Top + ANode.ParentNode.FCompSize.Padding.Bottom);
  end;
  ANode.FCompSize.Position.Left := AutoToZero(ANode.CalcLength(cs.Left, PW));
  ANode.FCompSize.Position.Top := AutoToZero(ANode.CalcLength(cs.Top, PH));
  ANode.FCompSize.Position.Right := AutoToZero(ANode.CalcLength(cs.Right, PW));
  ANode.FCompSize.Position.Bottom := AutoToZero(ANode.CalcLength(cs.Bottom, PH));

  // margins (percentage is relative to width also for top and bottom), auto margins are 0 here
  R.Top := AutoToZero(ANode.CalcLength(cs.Margin[csTop], ParentWidth));
  R.Left := AutoToZero(ANode.CalcLength(cs.Margin[csLeft], ParentWidth));
  R.Right := AutoToZero(ANode.CalcLength(cs.Margin[csRight], ParentWidth));
  R.Bottom := AutoToZero(ANode.CalcLength(cs.Margin[csBottom], ParentWidth));
  ANode.FCompSize.Margin := R;

  R.Top := AutoToZero(ANode.CalcLength(cs.Padding[csTop], ParentWidth));
  R.Left := AutoToZero(ANode.CalcLength(cs.Padding[csLeft], ParentWidth));
  R.Right := AutoToZero(ANode.CalcLength(cs.Padding[csRight], ParentWidth));
  R.Bottom := AutoToZero(ANode.CalcLength(cs.Padding[csBottom], ParentWidth));
  ANode.CompSize.Padding := R;

  R.Top := ANode.BorderWidth(csTop);
  R.Left := ANode.BorderWidth(csLeft);
  R.Right := ANode.BorderWidth(csRight);
  R.Bottom := ANode.BorderWidth(csBottom);
  ANode.CompSize.Border := R;

  HorzSpace := ANode.CompSize.Padding.Left + ANode.CompSize.Padding.Right + ANode.CompSize.Border.Left + ANode.CompSize.Border.Right;
  VertSpace := ANode.CompSize.Padding.Top + ANode.CompSize.Padding.Bottom + ANode.CompSize.Border.Top + ANode.CompSize.Border.Bottom;

  ANode.CalculateSize(cW, cH, cB);      // return -1, -1, 0 if node doesn't have own sizes. TextNode have own size (text size)
  TextW := cW;
  TextH := cH;
  LineH := cH;                          // height of one line of text
  // if width/height is set in this node owerrite
  if ANode.FLayoutRoot then begin    // size of root node is set by LayoutTo
    if ANode.FLayoutWidth >= 0 then cW := ANode.FLayoutWidth;
    if ANode.FLayoutHeight >= 0 then cH := ANode.FLayoutHeight;
  end else
  if SpecifiedSize(cs.Width, ParentWidth, HorzSpace) >= 0 then
    cW := SpecifiedSize(cs.Width, ParentWidth, HorzSpace)
  else
  if (cs.Width.LengthType in [cltUndefined, cltAuto]) and (ParentWidth <> -1) and (cs.Display in [cdtBlock, cdtFlex, cdtGrid]) and
     (not InFlex) and not (cs.Float in [cftLeft, cftRight]) and not (cs.Position in [cpAbsolute, cpFixed]) then
    cW := Max(0, ParentWidth - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace);
  if not ANode.FLayoutRoot then begin
    cW := Constrain(cW, cs.MinWidth, cs.MaxWidth, ParentWidth, HorzSpace);
    // height
    if SpecifiedSize(cs.Height, ParentHeight, VertSpace) >= 0 then
      cH := SpecifiedSize(cs.Height, ParentHeight, VertSpace);
    cH := Constrain(cH, cs.MinHeight, cs.MaxHeight, ParentHeight, VertSpace);
  end;
  // absolute node with left and right (top and bottom) is stretched, eg. inset-0
  if (cs.Position in [cpAbsolute, cpFixed]) and not ANode.FLayoutRoot then begin
    if (cW = -1) and (PW >= 0) and not (cs.Left.LengthType in [cltUndefined, cltAuto]) and not (cs.Right.LengthType in [cltUndefined, cltAuto]) then
      cW := Max(0, PW - ANode.FCompSize.Position.Left - ANode.FCompSize.Position.Right - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace);
    if (cH = -1) and (PH >= 0) and not (cs.Top.LengthType in [cltUndefined, cltAuto]) and not (cs.Bottom.LengthType in [cltUndefined, cltAuto]) then
      cH := Max(0, PH - ANode.FCompSize.Position.Top - ANode.FCompSize.Position.Bottom - ANode.CompSize.TopSpace - ANode.CompSize.BottomSpace);
  end;
  if AForceWidth >= 0 then cW := Max(0, AForceWidth - HorzSpace);
  if AForceHeight >= 0 then cH := Max(0, AForceHeight - VertSpace);
  // aspect-ratio: height from width
  if (cs.AspectRatio > 0) and (cW >= 0) and (AForceHeight < 0) and (SpecifiedSize(cs.Height, ParentHeight, VertSpace) < 0) then
    if cs.BoxSizing = cbxBorderBox then cH := Max(0, Round((cW + HorzSpace) / cs.AspectRatio) - VertSpace)
      else cH := Round(cW / cs.AspectRatio);

  // image keeps aspect ratio if only one size is set
  if (ANode.FElementName = 'img') and (TextW > 0) and (TextH > 0) then begin
    if (SpecifiedSize(cs.Width, ParentWidth, HorzSpace) >= 0) and (SpecifiedSize(cs.Height, ParentHeight, VertSpace) < 0) then
      cH := Round(cW * TextH / TextW)
    else if (SpecifiedSize(cs.Height, ParentHeight, VertSpace) >= 0) and (SpecifiedSize(cs.Width, ParentWidth, HorzSpace) < 0) then
      cW := Round(cH * TextW / TextH);
  end;
  // wrap text if there is not enough space
  if (ANode.FText <> '') and (ANode.FChildCount = 0) and (cs.WhiteSpace = cwsNormal) and (ANode.FAlignControl = nil) then begin
    if cW >= 0 then AvailW := cW
      else if ParentWidth > 0 then AvailW := ParentWidth - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace
      else AvailW := -1;
    if (AvailW > 0) and (TextW > AvailW) then begin
      ANode.MeasureText(AvailW, TextW, TextH, cB);
      // line-clamp: text is cut with ellipsis
      // line-clamp: height of N lines (text with ellipsis is computed when painted)
      if (cs.LineClamp > 0) and (LineH > 0) then
        TextH := Min(TextH, ANode.ClampLinesHeight(cs.LineClamp));
      if cW < 0 then cW := TextW;
      if SpecifiedSize(cs.Height, ParentHeight, VertSpace) < 0 then
        cH := Constrain(TextH, cs.MinHeight, cs.MaxHeight, ParentHeight, VertSpace);
    end;
  end;

  // if node have childrens calculate childrens required space
  if ANode.FChildCount > 0 then begin
    if cs.Position in [cpAbsolute, cpFixed] then
      // absolute node: shrink to fit content (stretched size is set above)
    else
    if (cs.Display in [cdtBlock, cdtFlex, cdtGrid]) and (cW = -1) and not InFlex then
      cW := ParentWidth;
    LayoutCalcPosition(ANode.FFirstChild, cW, cH, childWidth, childHeight);
    // wrapped content of absolute node is not wider than containing block
    if (cW = -1) and (cs.Position in [cpAbsolute, cpFixed]) and (cs.WhiteSpace = cwsNormal) and (PW > 0) and
      (childWidth > PW - ANode.FCompSize.Position.Left - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace) then begin
      cW := Max(1, PW - ANode.FCompSize.Position.Left - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace);
      LayoutCalcPosition(ANode.FFirstChild, cW, cH, childWidth, childHeight);
    end;
    if cW = -1 then cW := Constrain(childWidth, cs.MinWidth, cs.MaxWidth, ParentWidth, HorzSpace);
    if cH = -1 then begin
      cH := Constrain(childHeight, cs.MinHeight, cs.MaxHeight, ParentHeight, VertSpace);
      // flex container is higher than its content (min-height): items are aligned in final height
      if (cs.Display in [cdtFlex, cdtInlineFlex, cdtGrid]) and (cH > childHeight) then
        LayoutCalcPosition(ANode.FFirstChild, cW, cH, childWidth, childHeight);
    end;
    cB := cH - ANode.FLastNode.CompSize.MarginRect.Bottom + ANode.FLastNode.CompSize.BaseLine + ANode.CompSize.BottomSpace; // TODO: not LastNode, but bottom right position node
  end else
    if cB > 0 then cB := cB + ANode.FCompSize.Padding.Bottom + ANode.FCompSize.Border.Bottom  + ANode.FCompSize.Margin.Bottom;
  if cW = -1 then cW := Constrain(0, cs.MinWidth, cs.MaxWidth, ParentWidth, HorzSpace);
  if cH = -1 then cH := Constrain(0, cs.MinHeight, cs.MaxHeight, ParentHeight, VertSpace);
  Inc(cW, HorzSpace);
  Inc(cH, VertSpace);
  ANode.FCompSize.BaseLine := cB;
  ANode.FCompSize.ContentWidth := cW;
  ANode.FCompSize.ContentHeight := cH;
  ANode.FLayState := Key;
  ANode.FLayWanted := Key;
  ANode.FLayWantedPW := ParentWidth;
  ANode.FLayWantedPH := ParentHeight;
  if Cached or (ANode = CSSLayoutRecompute) then begin
    if ANode.FLayCount <= High(ANode.FLayResults) then Inc(ANode.FLayCount);
    for I := ANode.FLayCount - 1 downto 1 do ANode.FLayResults[I] := ANode.FLayResults[I - 1];   // newest first
    with ANode.FLayResults[0] do begin
      Key := ANode.FLayState;
      Margin := ANode.FCompSize.Margin;
      Padding := ANode.FCompSize.Padding;
      Border := ANode.FCompSize.Border;
      Position := ANode.FCompSize.Position;
      BaseLine := cB;
      ContentWidth := cW;
      ContentHeight := cH;
    end;
  end;
end;

procedure THtmlNode.IntSetAlignControl(AValue: TControl);
begin
  if FAlignControl = AValue then exit;
  FAlignControl := AValue;
  Changed;
end;


(*
  Flexible box layout https://www.w3.org/TR/css-flexbox-1/#layout-algorithm (simplified)
  AWidth, AHeight - inner size of flex container (-1 = not known)
  NewWidth, NewHeight - used inner size of flex container
*)
procedure THtmlNode.LayoutDoFlexAlign(AParentNode: THtmlNode; AList: TList; AWidth, AHeight: Integer; out NewWidth, NewHeight: Integer);
type
  TFlexItem = record
    Node: THtmlNode;
    Main, Cross: Integer;         // border box size
    MarginMainStart, MarginMainEnd, MarginCrossStart, MarginCrossEnd: Integer;
    AutoMainStart, AutoMainEnd, AutoCrossStart, AutoCrossEnd: Boolean;
    Base: Integer;                // flex base size (border box)
    AutoMin: Integer;             // automatic minimum size (min-content width, content height)
    Pos, CrossPos: Integer;       // margin box position in line
    Frozen: Boolean;
  end;
  TFlexLine = record
    First, Last: Integer;         // items index
    CrossSize: Integer;
    CrossPos: Integer;
  end;
var
  ps: TCSSItem;
  IsRow, IsReverse: Boolean;
  MainSize, CrossSize: Integer;   // container inner size (-1 = auto)
  MainGap, CrossGap: Integer;
  Items: array of TFlexItem;
  Lines: array of TFlexLine;
  N, I, J, L: Integer;
  Node: THtmlNode;
  Justify: TCSSJustifyContent;

  function ItemMain(ANode: THtmlNode): Integer; inline;
  begin
    if IsRow then Result := ANode.FCompSize.ContentWidth else Result := ANode.FCompSize.ContentHeight;
  end;
  function ItemCross(ANode: THtmlNode): Integer; inline;
  begin
    if IsRow then Result := ANode.FCompSize.ContentHeight else Result := ANode.FCompSize.ContentWidth;
  end;
  function OuterMain(const AItem: TFlexItem): Integer; inline;
  begin
    Result := AItem.Main + AItem.MarginMainStart + AItem.MarginMainEnd;
  end;
  function OuterCross(const AItem: TFlexItem): Integer; inline;
  begin
    Result := AItem.Cross + AItem.MarginCrossStart + AItem.MarginCrossEnd;
  end;
  // layout item with forced main and/or cross size (border box, -1 = auto)
  procedure LayoutItem(var AItem: TFlexItem; AMain, ACross: Integer);
  begin
    if IsRow then LayoutGetNodeSize(AItem.Node, AWidth, AHeight, True, AMain, ACross)
      else LayoutGetNodeSize(AItem.Node, AWidth, AHeight, True, ACross, AMain);
    AItem.Main := ItemMain(AItem.Node);
    AItem.Cross := ItemCross(AItem.Node);
  end;
  function ItemAlign(const AItem: TFlexItem): TCSSAlignItems;
  begin
    Result := AItem.Node.FCompStyle.AlignSelf;
    if Result = caiAuto then Result := ps.AlignItems;
    if (Result = caiBaseline) and not IsRow then Result := caiFlexStart;
  end;
  function CrossIsAuto(const AItem: TFlexItem): Boolean;
  var
    L: TCSSLength;
  begin
    if IsRow then L := AItem.Node.FCompStyle.Height else L := AItem.Node.FCompStyle.Width;
    Result := L.LengthType in [cltUndefined, cltAuto];
  end;
  function ClampMain(const AItem: TFlexItem; AValue: Integer): Integer;
  var
    cs: TCSSItem;
    Mn, Mx: TCSSLength;
    Space, V, Parent: Integer;
  begin
    cs := AItem.Node.FCompStyle;
    if IsRow then begin
      Mn := cs.MinWidth; Mx := cs.MaxWidth; Parent := AWidth;
      Space := AItem.Node.FCompSize.Padding.Left + AItem.Node.FCompSize.Padding.Right + AItem.Node.FCompSize.Border.Left + AItem.Node.FCompSize.Border.Right;
    end else begin
      Mn := cs.MinHeight; Mx := cs.MaxHeight; Parent := AHeight;
      Space := AItem.Node.FCompSize.Padding.Top + AItem.Node.FCompSize.Padding.Bottom + AItem.Node.FCompSize.Border.Top + AItem.Node.FCompSize.Border.Bottom;
    end;
    Result := Max(AValue, Space);
    // automatic minimum size of flex items (min-width/min-height: auto) is min-content size
    if (Mn.LengthType in [cltUndefined, cltAuto]) and (cs.Overflow = cotVisible) and (cs.OverflowY = cotVisible) then
      Result := Max(Result, AItem.AutoMin);
    if not ((Mx.LengthType = cltPercentage) and (Parent < 0)) and (Mx.LengthType in [cltPx, cltPt, cltEm, cltRem, cltPercentage]) then begin
      V := AItem.Node.CalcLength(Mx, Parent);
      if cs.BoxSizing = cbxContentBox then Inc(V, Space);
      Result := Min(Result, V);
    end;
    if not ((Mn.LengthType = cltPercentage) and (Parent < 0)) and (Mn.LengthType in [cltPx, cltPt, cltEm, cltRem, cltPercentage]) then begin
      V := AItem.Node.CalcLength(Mn, Parent);
      if cs.BoxSizing = cbxContentBox then Inc(V, Space);
      Result := Max(Result, V);
    end;
  end;
  procedure ResolveFlexibleLengths(var ALine: TFlexLine);
  var
    I, FreeSpace, Used, Loop: Integer;
    SumGrow, SumShrink: Double;
    Changed: Boolean;
    Target: Integer;
  begin
    if MainSize < 0 then Exit;
    for I := ALine.First to ALine.Last do Items[I].Frozen := False;
    for Loop := 1 to 5 do begin       // loop until all min/max constraints are satisfied
      Used := MainGap * (ALine.Last - ALine.First);
      SumGrow := 0;
      SumShrink := 0;
      for I := ALine.First to ALine.Last do begin
        if Items[I].Frozen then
          Inc(Used, OuterMain(Items[I]))
        else begin
          Inc(Used, Items[I].Base + Items[I].MarginMainStart + Items[I].MarginMainEnd);
          SumGrow := SumGrow + Items[I].Node.FCompStyle.FlexGrow;
          SumShrink := SumShrink + Items[I].Node.FCompStyle.FlexShrink * Items[I].Base;
        end;
      end;
      FreeSpace := MainSize - Used;
      Changed := False;
      for I := ALine.First to ALine.Last do begin
        if Items[I].Frozen then Continue;
        Target := Items[I].Base;
        if (FreeSpace > 0) and (SumGrow > 0) then
          Target := Items[I].Base + Round(FreeSpace * Items[I].Node.FCompStyle.FlexGrow / SumGrow)
        else
        if (FreeSpace < 0) and (SumShrink > 0) then
          Target := Items[I].Base - Round(-FreeSpace * Items[I].Node.FCompStyle.FlexShrink * Items[I].Base / SumShrink);
        Items[I].Main := ClampMain(Items[I], Target);
        if Items[I].Main <> Target then begin     // min/max violation, freeze item and distribute rest again
          Items[I].Frozen := True;
          Changed := True;
        end;
      end;
      if not Changed then Break;
    end;
  end;
  procedure SortByOrder;
  var
    I, J: Integer;
    T: TFlexItem;
  begin
    for I := 1 to High(Items) do begin    // stable insertion sort
      T := Items[I];
      J := I - 1;
      while (J >= 0) and (Items[J].Node.FCompStyle.Order > T.Node.FCompStyle.Order) do begin
        Items[J + 1] := Items[J];
        Dec(J);
      end;
      Items[J + 1] := T;
    end;
  end;
var
  cs: TCSSItem;
  sz: THtmlSize;
  Basis: TCSSLength;
  Space, LineMain, LineCross, FreeSpace, AutoCount, X, Y, Step, MaxAscent, Asc, TotalCross, MaxMain, NewMain: Integer;
  Align: TCSSAlignItems;
  Temp: TFlexItem;
  R: TRect;
  AbsNodes: array of THtmlNode;
begin
  AbsNodes := nil;
  ps := AParentNode.FCompStyle;
  IsRow := ps.FlexDirection in [cfdRow, cfdRowReverse];
  IsReverse := ps.FlexDirection in [cfdRowReverse, cfdColumnReverse];
  if IsRow then begin
    MainSize := AWidth; CrossSize := AHeight;
    MainGap := AParentNode.CalcLength(ps.ColumnGap, AWidth);
    CrossGap := AParentNode.CalcLength(ps.RowGap, AHeight);
  end else begin
    MainSize := AHeight; CrossSize := AWidth;
    MainGap := AParentNode.CalcLength(ps.RowGap, AHeight);
    CrossGap := AParentNode.CalcLength(ps.ColumnGap, AWidth);
  end;
  if (MainGap < 0) or (MainGap = MaxInt) then MainGap := 0;
  if (CrossGap < 0) or (CrossGap = MaxInt) then CrossGap := 0;

  // collect items and compute hypothetical sizes
  Items := nil;
  for I := 0 to AList.Count - 1 do begin
    Node := THtmlNode(AList[I]);
    if (Node.FCompStyle.Display = cdtNone) or Node.IsWhiteSpaceText then begin
      Node.FCompSize.ContentRect := Rect(0, 0, 0, 0);
      Node.FCompSize.MarginRect := Rect(0, 0, 0, 0);
      Continue;
    end;
    LayoutGetNodeSize(Node, AWidth, AHeight, True);
    if Node.FCompStyle.Position in [cpAbsolute, cpFixed] then begin    // positioned when size of container is known
      SetLength(AbsNodes, Length(AbsNodes) + 1);
      AbsNodes[High(AbsNodes)] := Node;
      Continue;
    end;
    SetLength(Items, Length(Items) + 1);
    with Items[High(Items)] do begin
      Node := THtmlNode(AList[I]);
      cs := Node.FCompStyle;
      sz := Node.FCompSize;
      if IsRow then begin
        MarginMainStart := sz.Margin.Left; MarginMainEnd := sz.Margin.Right;
        MarginCrossStart := sz.Margin.Top; MarginCrossEnd := sz.Margin.Bottom;
        AutoMainStart := cs.Margin[csLeft].LengthType = cltAuto; AutoMainEnd := cs.Margin[csRight].LengthType = cltAuto;
        AutoCrossStart := cs.Margin[csTop].LengthType = cltAuto; AutoCrossEnd := cs.Margin[csBottom].LengthType = cltAuto;
        Space := sz.Padding.Left + sz.Padding.Right + sz.Border.Left + sz.Border.Right;
      end else begin
        MarginMainStart := sz.Margin.Top; MarginMainEnd := sz.Margin.Bottom;
        MarginCrossStart := sz.Margin.Left; MarginCrossEnd := sz.Margin.Right;
        AutoMainStart := cs.Margin[csTop].LengthType = cltAuto; AutoMainEnd := cs.Margin[csBottom].LengthType = cltAuto;
        AutoCrossStart := cs.Margin[csLeft].LengthType = cltAuto; AutoCrossEnd := cs.Margin[csRight].LengthType = cltAuto;
        Space := sz.Padding.Top + sz.Padding.Bottom + sz.Border.Top + sz.Border.Bottom;
      end;
      Main := ItemMain(Node);
      Cross := ItemCross(Node);
      // flex base size
      Basis := cs.FlexBasis;
      if (Basis.LengthType = cltPercentage) and (MainSize < 0) then Basis.LengthType := cltAuto;
      if Basis.LengthType in [cltPx, cltPt, cltEm, cltRem, cltPercentage] then begin
        Base := Node.CalcLength(Basis, MainSize);
        if cs.BoxSizing = cbxContentBox then Inc(Base, Space);
      end else
        Base := Main;
    end;
  end;
  N := Length(Items);
  SortByOrder;

  // column direction with stretched items: width is known before height
  if (not IsRow) and (CrossSize >= 0) then
    for I := 0 to N - 1 do
      if (ItemAlign(Items[I]) = caiStretch) and CrossIsAuto(Items[I]) and not (Items[I].AutoCrossStart or Items[I].AutoCrossEnd) then begin
        LayoutItem(Items[I], -1, Max(0, CrossSize - Items[I].MarginCrossStart - Items[I].MarginCrossEnd));
        if Items[I].Node.FCompStyle.FlexBasis.LengthType in [cltAuto, cltUndefined] then Items[I].Base := Items[I].Main;
      end;
  // automatic minimum: min-content width in row, content height in column (if height is not set)
  for I := 0 to N - 1 do
    if IsRow then Items[I].AutoMin := Items[I].Node.MinContentWidth(True)
    else if Items[I].Node.FCompStyle.Height.LengthType in [cltUndefined, cltAuto] then Items[I].AutoMin := Items[I].Main
    else Items[I].AutoMin := 0;
  for I := 0 to N - 1 do Items[I].Base := ClampMain(Items[I], Items[I].Base);

  // collect lines
  Lines := nil;
  I := 0;
  while I < N do begin
    SetLength(Lines, Length(Lines) + 1);
    L := High(Lines);
    Lines[L].First := I;
    LineMain := Items[I].Base + Items[I].MarginMainStart + Items[I].MarginMainEnd;
    J := I + 1;
    if (ps.FlexWrap <> cfwNoWrap) and (MainSize >= 0) then
      while (J < N) and (LineMain + MainGap + Items[J].Base + Items[J].MarginMainStart + Items[J].MarginMainEnd <= MainSize) do begin
        Inc(LineMain, MainGap + Items[J].Base + Items[J].MarginMainStart + Items[J].MarginMainEnd);
        Inc(J);
      end
    else
      J := N;
    Lines[L].Last := J - 1;
    I := J;
  end;

  // resolve main sizes and layout items with new sizes
  for L := 0 to High(Lines) do begin
    for I := Lines[L].First to Lines[L].Last do Items[I].Main := Items[I].Base;
    ResolveFlexibleLengths(Lines[L]);
    LineCross := 0;
    for I := Lines[L].First to Lines[L].Last do begin
      if (Items[I].Main <> ItemMain(Items[I].Node)) or (MainSize >= 0) then
        LayoutItem(Items[I], Items[I].Main, -1);
      LineCross := Max(LineCross, OuterCross(Items[I]));
    end;
    Lines[L].CrossSize := LineCross;
  end;
  if (Length(Lines) = 1) and (CrossSize >= 0) then Lines[0].CrossSize := CrossSize;   // single line uses whole container

  // baseline (row only) and cross axis alignment
  for L := 0 to High(Lines) do begin
    // stretch items
    for I := Lines[L].First to Lines[L].Last do
      if (ItemAlign(Items[I]) = caiStretch) and CrossIsAuto(Items[I]) and not (Items[I].AutoCrossStart or Items[I].AutoCrossEnd) and
        (Items[I].Cross <> Lines[L].CrossSize - Items[I].MarginCrossStart - Items[I].MarginCrossEnd) then
        LayoutItem(Items[I], Items[I].Main, Max(0, Lines[L].CrossSize - Items[I].MarginCrossStart - Items[I].MarginCrossEnd));
    MaxAscent := 0;
    for I := Lines[L].First to Lines[L].Last do
      if ItemAlign(Items[I]) = caiBaseline then
        MaxAscent := Max(MaxAscent, OuterCross(Items[I]) - Items[I].Node.FCompSize.BaseLine);
    for I := Lines[L].First to Lines[L].Last do begin
      FreeSpace := Lines[L].CrossSize - OuterCross(Items[I]);
      if Items[I].AutoCrossStart and Items[I].AutoCrossEnd then Items[I].CrossPos := Max(0, FreeSpace) div 2
      else if Items[I].AutoCrossStart then Items[I].CrossPos := Max(0, FreeSpace)
      else if Items[I].AutoCrossEnd then Items[I].CrossPos := 0
      else
      case ItemAlign(Items[I]) of
        caiCenter: Items[I].CrossPos := FreeSpace div 2;
        caiFlexEnd: Items[I].CrossPos := FreeSpace;
        caiBaseline: begin
          Asc := OuterCross(Items[I]) - Items[I].Node.FCompSize.BaseLine;
          Items[I].CrossPos := MaxAscent - Asc;
        end;
        else Items[I].CrossPos := 0;
      end;
      if ItemAlign(Items[I]) = caiBaseline then
        Lines[L].CrossSize := Max(Lines[L].CrossSize, Items[I].CrossPos + OuterCross(Items[I]));
    end;
  end;

  // lines position (align-content: flex-start)
  TotalCross := 0;
  for L := 0 to High(Lines) do begin
    if L > 0 then Inc(TotalCross, CrossGap);
    Lines[L].CrossPos := TotalCross;
    Inc(TotalCross, Lines[L].CrossSize);
  end;
  if ps.FlexWrap = cfwWrapReverse then
    for L := 0 to High(Lines) do
      Lines[L].CrossPos := TotalCross - Lines[L].CrossPos - Lines[L].CrossSize;

  // main axis alignment
  Justify := ps.JustifyContent;
  MaxMain := 0;
  for L := 0 to High(Lines) do begin
    LineMain := MainGap * (Lines[L].Last - Lines[L].First);
    AutoCount := 0;
    for I := Lines[L].First to Lines[L].Last do begin
      Inc(LineMain, OuterMain(Items[I]));
      if Items[I].AutoMainStart then Inc(AutoCount);
      if Items[I].AutoMainEnd then Inc(AutoCount);
    end;
    if MainSize >= 0 then FreeSpace := MainSize - LineMain else FreeSpace := 0;
    MaxMain := Max(MaxMain, LineMain);
    X := 0;
    Step := 0;
    if (AutoCount > 0) and (FreeSpace > 0) then begin
      Step := FreeSpace div AutoCount;         // auto margins take all free space
      FreeSpace := 0;
    end else
    if FreeSpace > 0 then
      case Justify of
        cjcFlexEnd: X := FreeSpace;
        cjcCenter: X := FreeSpace div 2;
        cjcSpaceAround: X := FreeSpace div (2 * (Lines[L].Last - Lines[L].First + 1));
        cjcSpaceEvenly: X := FreeSpace div (Lines[L].Last - Lines[L].First + 2);
      end
    else
    if (FreeSpace < 0) and (Justify = cjcCenter) then X := FreeSpace div 2
    else if (FreeSpace < 0) and (Justify = cjcFlexEnd) then X := FreeSpace;    // content overflows at start
    for I := Lines[L].First to Lines[L].Last do begin
      if Items[I].AutoMainStart then Inc(X, Step);
      Items[I].Pos := X;
      Inc(X, OuterMain(Items[I]) + MainGap);
      if Items[I].AutoMainEnd then Inc(X, Step);
      if (FreeSpace > 0) and (I < Lines[L].Last) then
        case Justify of
          cjcSpaceBetween: Inc(X, FreeSpace div Max(1, Lines[L].Last - Lines[L].First));
          cjcSpaceAround: Inc(X, FreeSpace div (Lines[L].Last - Lines[L].First + 1));
          cjcSpaceEvenly: Inc(X, FreeSpace div (Lines[L].Last - Lines[L].First + 2));
        end;
    end;
  end;
  if MainSize >= 0 then NewMain := MainSize else NewMain := MaxMain;

  // set node positions
  for L := 0 to High(Lines) do
    for I := Lines[L].First to Lines[L].Last do begin
      X := Items[I].Pos;
      if IsReverse then X := NewMain - X - OuterMain(Items[I]);
      Y := Lines[L].CrossPos + Items[I].CrossPos;
      if IsRow then R := Rect(X, Y, X + OuterMain(Items[I]), Y + OuterCross(Items[I]))
        else R := Rect(Y, X, Y + OuterCross(Items[I]), X + OuterMain(Items[I]));
      sz := Items[I].Node.FCompSize;
      sz.MarginRect := R;
      sz.ContentRect := Rect(R.Left + sz.Margin.Left, R.Top + sz.Margin.Top, R.Right - sz.Margin.Right, R.Bottom - sz.Margin.Bottom);
      if Items[I].Node.FCompStyle.Position = cpRelative then begin
        OffsetRect(sz.MarginRect, sz.Position.Left - sz.Position.Right * Ord(Items[I].Node.FCompStyle.Left.LengthType in [cltUndefined, cltAuto]), sz.Position.Top);
        OffsetRect(sz.ContentRect, sz.Position.Left - sz.Position.Right * Ord(Items[I].Node.FCompStyle.Left.LengthType in [cltUndefined, cltAuto]), sz.Position.Top);
      end;
    end;

  if IsRow then begin
    NewWidth := NewMain;
    NewHeight := TotalCross;
  end else begin
    NewWidth := TotalCross;
    NewHeight := NewMain;
  end;
  if (CrossSize >= 0) then begin
    if IsRow then NewHeight := Max(NewHeight, CrossSize) else NewWidth := Max(NewWidth, CrossSize);
  end;
  // absolute nodes are positioned relative to container
  for I := 0 to High(AbsNodes) do begin
    if AWidth >= 0 then X := AWidth else X := NewWidth;
    if AHeight >= 0 then Y := AHeight else Y := NewHeight;
    AbsNodes[I].PlaceAbsolute(X, Y);
  end;
end;

function THtmlNode.IsWhiteSpaceText: Boolean;
begin
  Result := (FElementName = '#text') and (FChildCount = 0) and (Trim(FText) = '');
end;

function THtmlNode.HasPrevElementSibling: Boolean;
var
  N: THtmlNode;
begin
  N := FPrevSibling;
  while Assigned(N) and N.IsWhiteSpaceText do N := N.FPrevSibling;
  Result := Assigned(N);
end;

(*
  line-clamp: height of ALines lines of wrapped text
*)
function MeasureCanvas: TCanvas;
begin
  if CSSMeasureBitmap = nil then begin
    CSSMeasureBitmap := TBitmap.Create;
    CSSMeasureBitmap.SetSize(1, 1);
  end;
  Result := CSSMeasureBitmap.Canvas;
end;

function WrappedTextHeight(ACanvas: TCanvas; const AText: String; AMaxWidth: Integer): Integer;
var
  R: TRect;
begin
  R := Rect(0, 0, Max(1, AMaxWidth), 0);
  DrawText(ACanvas.Handle, PChar(AText), Length(AText), R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX or DT_LEFT);
  Result := R.Height;
end;

function THtmlNode.ClampLinesHeight(ALines: Integer): Integer;
var
  Canvas: TCanvas;
begin
  Canvas := MeasureCanvas;
  AssignFontTo(Canvas.Font);
  Result := WrappedTextHeight(Canvas, 'W'#10'W', 1000) * ALines div 2;   // line height with leading
end;

(*
  white-space: nowrap: longest beginning of text with ellipsis which fits to width (DrawText of Cocoa ignores
  DT_END_ELLIPSIS). Cached like ClampedText (a node has line-clamp or nowrap, not both).
*)
function THtmlNode.EllipsisText(AMaxWidth: Integer): String;
const
  ELLIPSIS = #$E2#$80#$A6;
var
  Lo, Hi, Mid: Integer;
  Canvas: TCanvas;
  Key: String;
begin
  Canvas := MeasureCanvas;
  AssignFontTo(Canvas.Font);
  Key := Format('e|%d|%s|%d|%d|%s', [AMaxWidth, Canvas.Font.Name, Canvas.Font.Height, Integer(Canvas.Font.Style), FText]);
  if Key = FClampKey then Exit(FClampResult);
  FClampKey := Key;
  Result := FText;
  if Canvas.TextWidth(FText) > AMaxWidth then begin
    Lo := 0;
    Hi := Length(FText);
    while Lo < Hi do begin
      Mid := (Lo + Hi + 1) div 2;
      if Canvas.TextWidth(Copy(FText, 1, Mid) + ELLIPSIS) <= AMaxWidth then Lo := Mid else Hi := Mid - 1;
    end;
    while (Lo > 0) and (Lo < Length(FText)) and (Ord(FText[Lo + 1]) and $C0 = $80) do Dec(Lo);   // whole UTF-8 char
    Result := TrimRight(Copy(FText, 1, Lo)) + ELLIPSIS;
  end;
  FClampResult := Result;
end;

(*
  line-clamp: longest beginning of text with ellipsis which fits to N lines (whole text when it fits).
  Computed when painted, cached for width, lines, font and text.
*)
function THtmlNode.ClampedText(AMaxWidth: Integer): String;
const
  ELLIPSIS = #$E2#$80#$A6;
var
  L, N, MaxH, FullH: Integer;
  Canvas: TCanvas;
  Key: String;
  function Fits(ALen: Integer): Boolean;
  begin
    Result := WrappedTextHeight(Canvas, TrimRight(Copy(FText, 1, ALen)) + ELLIPSIS, AMaxWidth) <= MaxH;
  end;
  // length of text up to the last space before position (whole words)
  function WordStart(APos: Integer): Integer;
  begin
    Result := Min(APos, Length(FText));
    while (Result > 0) and (FText[Result] <> ' ') do Dec(Result);
  end;
  // length of text with next word
  function WordEnd(APos: Integer): Integer;
  begin
    Result := APos + 1;
    while (Result < Length(FText)) and (FText[Result + 1] <> ' ') do Inc(Result);
  end;
begin
  Canvas := MeasureCanvas;
  AssignFontTo(Canvas.Font);
  Key := Format('%d|%d|%s|%d|%d|%s', [AMaxWidth, FCompStyle.LineClamp, Canvas.Font.Name, Canvas.Font.Height, Integer(Canvas.Font.Style), FText]);
  if Key = FClampKey then Exit(FClampResult);
  FClampKey := Key;
  MaxH := WrappedTextHeight(Canvas, 'W'#10'W', 1000) * FCompStyle.LineClamp div 2;
  Result := FText;
  FullH := WrappedTextHeight(Canvas, FText, AMaxWidth);
  if FullH > MaxH then begin
    // estimate from heights, then whole words are added or removed (usually 2 or 3 measurements)
    L := WordStart(Round(Length(FText) * MaxH / FullH * 1.05));
    if Fits(L) then begin
      repeat
        N := WordEnd(L);
        if (N > L) and (N < Length(FText)) and Fits(N) then L := N else Break;
      until False;
    end else
      repeat
        L := WordStart(L - 1);
      until (L <= 0) or Fits(L);
    Result := TrimRight(Copy(FText, 1, L)) + ELLIPSIS;
  end;
  FClampResult := Result;
end;

(*
  Grid layout (KISS subset of CSS grid): grid-template-columns and grid-template-rows with px, %, rem, fr,
  auto, minmax(min, max) (max is used) and repeat(N, ...), automatic placement row by row, column and row
  spans, gaps, align-items/align-self in cells (stretch, start, center, end).
  Not supported: line numbers and names, template areas, auto-fill/auto-fit, dense placement, justify-items.
  AWidth, AHeight - inner size of grid container (-1 = not known)
*)
procedure THtmlNode.LayoutDoGrid(AParentNode: THtmlNode; AList: TList; AWidth, AHeight: Integer; out NewWidth, NewHeight: Integer);
type
  TGridTrack = record
    Kind: Integer;              // 0 = length, 1 = fr, 2 = auto
    Value: Single;              // px or fr
    Size, Pos: Integer;
  end;
  TGridTracks = array of TGridTrack;
  TGridItem = record
    Node: THtmlNode;
    Col, Row, ColSpan, RowSpan: Integer;
    ForceW: Integer;            // forced border box width (-1 = own width)
  end;
var
  ps: TCSSItem;
  Cols, Rows: TGridTracks;
  Items: array of TGridItem;
  AbsNodes: array of THtmlNode;
  Used: array of array of Boolean;     // occupied cells [row][col]
  ColGap, RowGap, I, J, R, C, NCols, X, Y, W, H, Need, CW, CH: Integer;
  Nd: THtmlNode;
  Align: TCSSAlignItems;
  sz: THtmlSize;

  function AutoToZeroInt(AValue: Integer): Integer; inline;
  begin
    if (AValue = MaxInt) or (AValue < -100000) then Result := 0 else Result := AValue;
  end;
  procedure ParseTracks(const ATemplate: String; ASize: Integer; var ATracks: TGridTracks);
    procedure Add(AToken: String);
    var
      T: TGridTrack;
      V: Integer;
    begin
      AToken := Trim(AToken);
      if AToken = '' then Exit;
      if Copy(AToken, 1, 7) = 'minmax(' then begin     // minmax(min, max): max is used
        AToken := Copy(AToken, 8, Length(AToken) - 8);
        while Pos(',', AToken) > 0 do AToken := StrAfter(AToken, ',');
        AToken := Trim(AToken);
      end;
      T := Default(TGridTrack);
      if AToken = 'auto' then T.Kind := 2
      else if (Length(AToken) > 2) and (Copy(AToken, Length(AToken) - 1, 2) = 'fr') then begin
        T.Kind := 1;
        T.Value := CSSStrToFloatDef(Copy(AToken, 1, Length(AToken) - 2), 1);
      end else begin
        V := AParentNode.CalcLength(CSSToLength(AToken), ASize);
        if (V < 0) or (V = MaxInt) then T.Kind := 2 else T.Value := V;
      end;
      SetLength(ATracks, Length(ATracks) + 1);
      ATracks[High(ATracks)] := T;
    end;
  var
    Parts, Inner, Sub: TStringArray;
    S: String;
    I, K, M: Integer;
  begin
    ATracks := nil;
    S := LowerCase(Trim(ATemplate));
    if (S = '') or (S = 'none') then Exit;
    Parts := SplitParameters(S, ' ');
    for I := 0 to High(Parts) do
      if Copy(Parts[I], 1, 7) = 'repeat(' then begin
        Inner := SplitParameters(Copy(Parts[I], 8, Length(Parts[I]) - 8), ',');
        if Length(Inner) < 2 then Continue;
        Sub := SplitParameters(Trim(Copy(Parts[I], Pos(',', Parts[I]) + 1, Length(Parts[I]) - Pos(',', Parts[I]) - 1)), ' ');
        for K := 1 to EnsureRange(StrToIntDef(Trim(Inner[0]), 1), 1, 100) do
          for M := 0 to High(Sub) do Add(Sub[M]);
      end else
        Add(Parts[I]);
  end;
  function AreaFree(ARow, ACol, AColSpan, ARowSpan: Integer): Boolean;
  var
    I, J: Integer;
  begin
    for I := ARow to ARow + ARowSpan - 1 do
      if I <= High(Used) then
        for J := ACol to ACol + AColSpan - 1 do
          if Used[I][J] then Exit(False);
    Result := True;
  end;
  procedure Mark(ARow, ACol, AColSpan, ARowSpan: Integer);
  var
    I, J: Integer;
  begin
    while High(Used) < ARow + ARowSpan - 1 do begin
      SetLength(Used, Length(Used) + 1);
      SetLength(Used[High(Used)], NCols);
    end;
    for I := ARow to ARow + ARowSpan - 1 do
      for J := ACol to ACol + AColSpan - 1 do Used[I][J] := True;
  end;
  // fr tracks share free space (rounding errors go to last track)
  procedure Distribute(var ATracks: TGridTracks; AFree: Integer; AKeepContent: Boolean);
  var
    I: Integer;
    FrSum, Acc, Prev: Single;
  begin
    FrSum := 0;
    for I := 0 to High(ATracks) do
      if ATracks[I].Kind = 1 then FrSum := FrSum + ATracks[I].Value;
    if (FrSum <= 0) or (AFree <= 0) then Exit;
    Acc := 0;
    for I := 0 to High(ATracks) do
      if ATracks[I].Kind = 1 then begin
        Prev := Acc;
        Acc := Acc + AFree * ATracks[I].Value / FrSum;
        if AKeepContent then ATracks[I].Size := Max(ATracks[I].Size, Round(Acc) - Round(Prev))
          else ATracks[I].Size := Round(Acc) - Round(Prev);
      end;
  end;
  function SpanSize(const ATracks: TGridTracks; AFirst, ACount, AGap: Integer): Integer;
  var
    I: Integer;
  begin
    Result := AGap * (ACount - 1);
    for I := AFirst to AFirst + ACount - 1 do Inc(Result, ATracks[I].Size);
  end;
  procedure SetPositions(var ATracks: TGridTracks; AGap: Integer);
  var
    I, P: Integer;
  begin
    P := 0;
    for I := 0 to High(ATracks) do begin
      ATracks[I].Pos := P;
      Inc(P, ATracks[I].Size + AGap);
    end;
  end;
begin
  ps := AParentNode.FCompStyle;
  ColGap := AParentNode.CalcLength(ps.ColumnGap, AWidth);
  RowGap := AParentNode.CalcLength(ps.RowGap, AHeight);
  if (ColGap < 0) or (ColGap = MaxInt) then ColGap := 0;
  if (RowGap < 0) or (RowGap = MaxInt) then RowGap := 0;
  ParseTracks(ResolveVars(ps.GridTemplateColumns), AWidth, Cols);
  if Length(Cols) = 0 then begin      // one column
    SetLength(Cols, 1);
    Cols[0].Kind := 1;
    Cols[0].Value := 1;
  end;
  NCols := Length(Cols);
  ParseTracks(ResolveVars(ps.GridTemplateRows), AHeight, Rows);

  // automatic placement: row by row, cursor doesn't go back (as grid-auto-flow: row)
  Items := nil;
  AbsNodes := nil;
  Used := nil;
  R := 0;
  C := 0;
  for I := 0 to AList.Count - 1 do begin
    Nd := THtmlNode(AList[I]);
    if (Nd.FCompStyle.Display = cdtNone) or Nd.IsWhiteSpaceText then begin
      Nd.FCompSize.ContentRect := Rect(0, 0, 0, 0);
      Nd.FCompSize.MarginRect := Rect(0, 0, 0, 0);
      Continue;
    end;
    if Nd.FCompStyle.Position in [cpAbsolute, cpFixed] then begin
      LayoutGetNodeSize(Nd, AWidth, AHeight, True);
      SetLength(AbsNodes, Length(AbsNodes) + 1);
      AbsNodes[High(AbsNodes)] := Nd;
      Continue;
    end;
    SetLength(Items, Length(Items) + 1);
    Items[High(Items)].Node := Nd;
    J := Nd.FCompStyle.GridColumnSpan;
    if (J < 0) or (J > NCols) then J := NCols else if J = 0 then J := 1;
    Items[High(Items)].ColSpan := J;
    Items[High(Items)].RowSpan := Max(1, Nd.FCompStyle.GridRowSpan);
    repeat
      if C + J > NCols then begin
        Inc(R);
        C := 0;
      end;
      if AreaFree(R, C, J, Items[High(Items)].RowSpan) then Break;
      Inc(C);
    until False;
    Items[High(Items)].Row := R;
    Items[High(Items)].Col := C;
    Mark(R, C, J, Items[High(Items)].RowSpan);
    Inc(C, J);
  end;
  while Length(Rows) < Length(Used) do begin    // implicit rows are auto
    SetLength(Rows, Length(Rows) + 1);
    Rows[High(Rows)] := Default(TGridTrack);
    Rows[High(Rows)].Kind := 2;
  end;

  // column sizes: fixed, auto (max-content of items in one column), fr (free space)
  for J := 0 to NCols - 1 do
    if Cols[J].Kind = 0 then Cols[J].Size := Round(Cols[J].Value) else Cols[J].Size := 0;
  for I := 0 to High(Items) do
    with Items[I] do
      if (ColSpan = 1) and ((Cols[Col].Kind = 2) or ((Cols[Col].Kind = 1) and (AWidth < 0))) then begin
        LayoutGetNodeSize(Node, -1, AHeight, True);
        sz := Node.FCompSize;
        Cols[Col].Size := Max(Cols[Col].Size, sz.ContentWidth + sz.Margin.Left + sz.Margin.Right);
      end;
  if AWidth >= 0 then begin
    W := AWidth - ColGap * (NCols - 1);
    for J := 0 to NCols - 1 do
      if Cols[J].Kind <> 1 then Dec(W, Cols[J].Size);
    Distribute(Cols, W, False);
  end;
  SetPositions(Cols, ColGap);

  // items in final width, row sizes from item heights
  for J := 0 to High(Rows) do
    if Rows[J].Kind = 0 then Rows[J].Size := Round(Rows[J].Value) else Rows[J].Size := 0;
  for I := 0 to High(Items) do
    with Items[I] do begin
      CW := SpanSize(Cols, Col, ColSpan, ColGap);
      if Node.FCompStyle.Width.LengthType in [cltUndefined, cltAuto] then begin
        ForceW := CW - AutoToZeroInt(Node.CalcLength(Node.FCompStyle.Margin[csLeft], CW)) -
          AutoToZeroInt(Node.CalcLength(Node.FCompStyle.Margin[csRight], CW));
        LayoutGetNodeSize(Node, CW, -1, True, ForceW, -1);
      end else begin
        ForceW := -1;
        LayoutGetNodeSize(Node, CW, -1, True);
      end;
      sz := Node.FCompSize;
      if (RowSpan = 1) and (Rows[Row].Kind <> 0) then
        Rows[Row].Size := Max(Rows[Row].Size, sz.ContentHeight + sz.Margin.Top + sz.Margin.Bottom);
    end;
  for I := 0 to High(Items) do    // item over more rows enlarges its last row
    with Items[I] do
      if RowSpan > 1 then begin
        Need := Node.FCompSize.ContentHeight + Node.FCompSize.Margin.Top + Node.FCompSize.Margin.Bottom - SpanSize(Rows, Row, RowSpan, RowGap);
        if Need > 0 then Inc(Rows[Row + RowSpan - 1].Size, Need);
      end;
  if AHeight >= 0 then begin
    H := AHeight - RowGap * Max(0, High(Rows));
    for J := 0 to High(Rows) do
      if Rows[J].Kind <> 1 then Dec(H, Rows[J].Size);
    Distribute(Rows, H, True);
  end;
  SetPositions(Rows, RowGap);

  // positions, align in cell (stretch by default)
  for I := 0 to High(Items) do
    with Items[I] do begin
      CW := SpanSize(Cols, Col, ColSpan, ColGap);
      CH := SpanSize(Rows, Row, RowSpan, RowGap);
      sz := Node.FCompSize;
      Align := Node.FCompStyle.AlignSelf;
      if Align = caiAuto then Align := ps.AlignItems;
      if (Align = caiStretch) and (Node.FCompStyle.Height.LengthType in [cltUndefined, cltAuto]) and
        (sz.ContentHeight + sz.Margin.Top + sz.Margin.Bottom <> CH) then begin
        LayoutGetNodeSize(Node, CW, CH, True, ForceW, CH - sz.Margin.Top - sz.Margin.Bottom);
        sz := Node.FCompSize;
      end;
      H := sz.ContentHeight + sz.Margin.Top + sz.Margin.Bottom;
      X := Cols[Col].Pos;
      Y := Rows[Row].Pos;
      case Align of
        caiCenter: Inc(Y, (CH - H) div 2);
        caiFlexEnd: Inc(Y, CH - H);
      end;
      sz.MarginRect := Rect(X, Y, X + sz.ContentWidth + sz.Margin.Left + sz.Margin.Right, Y + H);
      sz.ContentRect := Rect(X + sz.Margin.Left, Y + sz.Margin.Top, sz.MarginRect.Right - sz.Margin.Right, Y + H - sz.Margin.Bottom);
      if Node.FCompStyle.Position = cpRelative then begin
        OffsetRect(sz.MarginRect, sz.Position.Left - sz.Position.Right * Ord(Node.FCompStyle.Left.LengthType in [cltUndefined, cltAuto]), sz.Position.Top);
        OffsetRect(sz.ContentRect, sz.Position.Left - sz.Position.Right * Ord(Node.FCompStyle.Left.LengthType in [cltUndefined, cltAuto]), sz.Position.Top);
      end;
    end;

  if AWidth >= 0 then NewWidth := AWidth else NewWidth := SpanSize(Cols, 0, NCols, ColGap);
  if Length(Rows) > 0 then NewHeight := SpanSize(Rows, 0, Length(Rows), RowGap) else NewHeight := 0;
  for I := 0 to High(AbsNodes) do begin
    if AWidth >= 0 then X := AWidth else X := NewWidth;
    if AHeight >= 0 then Y := AHeight else Y := NewHeight;
    AbsNodes[I].PlaceAbsolute(X, Y);
  end;
end;

(*
  Position of absolute node in container with inner size AWidth x AHeight (left, top, right, bottom)
*)
procedure THtmlNode.PlaceAbsolute(AWidth, AHeight: Integer);
var
  sz: THtmlSize;
  X, Y: Integer;
  Pad: TRect;
begin
  sz := FCompSize;
  // containing block is padding box of parent (coordinates are relative to its content box)
  if Assigned(ParentNode) then Pad := ParentNode.FCompSize.Padding else Pad := Rect(0, 0, 0, 0);
  // insets in percent: size of container is known now
  if FCompStyle.Left.LengthType = cltPercentage then sz.Position.Left := CalcLength(FCompStyle.Left, AWidth + Pad.Left + Pad.Right);
  if FCompStyle.Right.LengthType = cltPercentage then sz.Position.Right := CalcLength(FCompStyle.Right, AWidth + Pad.Left + Pad.Right);
  if FCompStyle.Top.LengthType = cltPercentage then sz.Position.Top := CalcLength(FCompStyle.Top, AHeight + Pad.Top + Pad.Bottom);
  if FCompStyle.Bottom.LengthType = cltPercentage then sz.Position.Bottom := CalcLength(FCompStyle.Bottom, AHeight + Pad.Top + Pad.Bottom);
  X := 0;
  Y := 0;
  if not (FCompStyle.Left.LengthType in [cltUndefined, cltAuto]) then X := sz.Position.Left - Pad.Left
  else if not (FCompStyle.Right.LengthType in [cltUndefined, cltAuto]) then
    X := AWidth + Pad.Right - sz.Position.Right - sz.ContentWidth - sz.Margin.Left - sz.Margin.Right;
  if not (FCompStyle.Top.LengthType in [cltUndefined, cltAuto]) then Y := sz.Position.Top - Pad.Top
  else if not (FCompStyle.Bottom.LengthType in [cltUndefined, cltAuto]) then
    Y := AHeight + Pad.Bottom - sz.Position.Bottom - sz.ContentHeight - sz.Margin.Top - sz.Margin.Bottom;
  sz.MarginRect := Rect(X, Y, X + sz.ContentWidth + sz.Margin.Left + sz.Margin.Right, Y + sz.ContentHeight + sz.Margin.Top + sz.Margin.Bottom);
  sz.ContentRect := Rect(sz.MarginRect.Left + sz.Margin.Left, sz.MarginRect.Top + sz.Margin.Top,
    sz.MarginRect.Right - sz.Margin.Right, sz.MarginRect.Bottom - sz.Margin.Bottom);
end;

procedure THtmlNode.LayoutCalcPosition(ANode: THtmlNode; TargetWidth, TargetHeight: Integer; out NewWidth, NewHeight: Integer);
var
  INode,
  ForNode: THtmlNode;
  IterationCounter: Integer;
  NeedIteration: Boolean;
  PrefWidth, PrefHeight,
  Dx, Dy: Integer;
  LeftOffset,
  RightOffset: TPoint; // offsets for float:left and float:right
  RowHeight: Integer;
  RealMargin,
  ContentBounds: TRect;
  cs: TCSSItem;
  GapList: TList;
  ParentIsFlex: Boolean;
  X, Y: Integer;
  Pad: TRect;
begin
  if not Assigned(ANode) then begin
    Exit;

  end;
  ForNode := ANode;   // backup node
  ParentIsFlex := Assigned(ANode.ParentNode) and (ANode.ParentNode.FCompStyle.Display in [cdtFlex, cdtInlineFlex]);
  if ParentIsFlex then begin // display mode flex
    INode := ANode;
    GapList := TList.Create;
    while Assigned(INode) do begin
      GapList.Add(INode);
      INode := INode.GetNext(INode);
    end;

    LayoutDoFlexAlign(ANode.ParentNode, GapList, TargetWidth, TargetHeight, NewWidth, NewHeight);
    GapList.Free;
    Exit;
  end;
  if Assigned(ANode.ParentNode) and (ANode.ParentNode.FCompStyle.Display = cdtGrid) then begin
    INode := ANode;
    GapList := TList.Create;
    while Assigned(INode) do begin
      GapList.Add(INode);
      INode := INode.GetNext(INode);
    end;
    LayoutDoGrid(ANode.ParentNode, GapList, TargetWidth, TargetHeight, NewWidth, NewHeight);
    GapList.Free;
    Exit;
  end;

  GapList := TList.Create;
  IterationCounter := 0;
  NewWidth := 0;
  NewHeight := 0;
  repeat
    ANode := ForNode;
    Dx := 0;
    Dy := 0;
    LeftOffset := Point(0,0);     // for float:left ?
    RightOffset := Point(0,0);    // for float:right ?
    RowHeight := 0;
    NeedIteration := False;
    while Assigned(ANode) do begin
      if ANode.FCompStyle.Display = cdtNone then begin
        ANode := ANode.GetNext(ANode, False);
        Continue;
      end;
      cs := ANode.FCompStyle;
      // we can't compute ContentWidth or ContentHeight (eg.: first node width:90% but targetwith is unknown yet (will be known after next iteration)
      if (not ANode.FLayoutRoot) and (((TargetWidth = -1) and (ANode.CompStyle.Width.LengthType = cltPercentage)) or
        ((TargetHeight = -1) and (ANode.CompStyle.Height.LengthType = cltPercentage))) then begin
        Dx := 0;
        Dy := 0;
        NeedIteration := True
      end
      else begin
        LayoutGetNodeSize(ANode, TargetWidth, TargetHeight); // TODO: this is correct size??
        PrefWidth := ANode.FCompSize.ContentWidth;
        PrefHeight := ANode.FCompSize.ContentHeight;
        RealMargin := ANode.FCompSize.Margin;
        // if we are using auto margins set it to zero
        if RealMargin.Left = MaxInt then RealMargin.Left := 0;
        if RealMargin.Top = MaxInt then RealMargin.Top := 0;
        if RealMargin.Right = MaxInt then RealMargin.Right := 0;
        if RealMargin.Bottom = MaxInt then RealMargin.Bottom := 0;
        if cs.Position in [cpAbsolute, cpFixed] then begin
          // absolute position is relative to parent node, static position is used if left/top is not set
          X := Dx + RealMargin.Left;
          Y := Dy + RealMargin.Top;
          // containing block is padding box of parent
          if Assigned(ANode.ParentNode) then Pad := ANode.ParentNode.FCompSize.Padding else Pad := Rect(0, 0, 0, 0);
          if not (cs.Left.LengthType in [cltUndefined, cltAuto]) then
            X := ANode.FCompSize.Position.Left - Pad.Left + RealMargin.Left
          else if not (cs.Right.LengthType in [cltUndefined, cltAuto]) and (TargetWidth >= 0) then
            X := TargetWidth + Pad.Right - ANode.FCompSize.Position.Right - PrefWidth - RealMargin.Right;
          if not (cs.Top.LengthType in [cltUndefined, cltAuto]) then
            Y := ANode.FCompSize.Position.Top - Pad.Top + RealMargin.Top
          else if not (cs.Bottom.LengthType in [cltUndefined, cltAuto]) and (TargetHeight >= 0) then
            Y := TargetHeight + Pad.Bottom - ANode.FCompSize.Position.Bottom - PrefHeight - RealMargin.Bottom;
          ContentBounds := Rect(X, Y, X + PrefWidth, Y + PrefHeight);
        end else begin
          if (cs.Float = cftRight) and (TargetWidth >= 0) then begin   // float right: stack from right side
            X := TargetWidth - RightOffset.x - PrefWidth - RealMargin.Right;
            ContentBounds := Rect(X, Dy, X + PrefWidth, Dy + PrefHeight);
            Inc(RightOffset.x, PrefWidth + RealMargin.Left + RealMargin.Right);
            RowHeight := Max(PrefHeight + RealMargin.Top + RealMargin.Bottom, RowHeight);
          end else
          if (cs.Display in [cdtInline, cdtInlineFlex]) or (cs.Float in [cftLeft, cftRight]) then begin
            if (TargetWidth =-1) or ((Dx + PrefWidth + RealMargin.Left + RealMargin.Right) <= (TargetWidth - RightOffset.x)) then begin
              ContentBounds := Rect(Dx, Dy, Dx + PrefWidth, Dy + PrefHeight);
              RowHeight := Max(PrefHeight + RealMargin.Top + RealMargin.Bottom, RowHeight);
              Inc(Dx, PrefWidth);
            end else begin // there is no space in current "line" move to next
              RowHeight :=  LayoutDoVerticalAlign(GapList);
              Inc(Dy, RowHeight);
              RightOffset.x := 0;
              RowHeight := PrefHeight + RealMargin.Top + RealMargin.Bottom;
              if Dy > LeftOffset.y then  LeftOffset.x := 0;
              Dx := LeftOffset.x;
              ContentBounds := Rect(Dx, Dy, Dx + PrefWidth, Dy + PrefHeight);
              Inc(Dx, PrefWidth);
            end;
            GapList.Add(ANode);
            Inc(ContentBounds.Left, RealMargin.Left);
            Inc(ContentBounds.Right, RealMargin.Left);
            Inc(Dx, RealMargin.Right);
            Inc(Dx, RealMargin.Left);
          end else begin    // block display: node use whole available space
            LayoutDoVerticalAlign(GapList);
            if ((Dx > 0) and (LeftOffset.x = 0)) or (RightOffset.x > 0) then Inc(Dy, RowHeight);
            RightOffset.x := 0;
            Dx := 0 + RealMargin.Left;
            ContentBounds := Rect(Dx, Dy, Dx + PrefWidth , Dy + PrefHeight); // new bounds  before margins
            RowHeight := 0;
            Inc(Dy, PrefHeight + RealMargin.Top + RealMargin.Bottom);
            Dx := 0;
          end;

          Inc(ContentBounds.Top, RealMargin.Top);
          Inc(ContentBounds.Bottom, RealMargin.Top);
          if ANode.CompStyle.Width.LengthType <> cltPercentage then
            NewWidth := Max(NewWidth, ContentBounds.Right+RealMargin.Right); // percentage width depends on parent, is not counted
          NewHeight := Max(NewHeight, ContentBounds.Bottom + RealMargin.Bottom);

        end;
        ANode.FCompSize.ContentRect := ContentBounds;
        ANode.FCompSize.MarginRect.TopLeft := Point(ANode.FCompSize.ContentRect.Left - ANode.FCompSize.Margin.Left, ANode.FCompSize.ContentRect.Top - ANode.FCompSize.Margin.Top);
        ANode.FCompSize.MarginRect.BottomRight := Point(ANode.FCompSize.ContentRect.Right + ANode.FCompSize.Margin.Right, ANode.FCompSize.ContentRect.Bottom + ANode.FCompSize.Margin.Bottom);
        if cs.Float = cftLeft then LeftOffset.x := Dx;
        RowHeight := Max(RowHeight, PrefHeight);
      end;
      ANode := ANode.GetNext(ANode, False);
    end;
    LayoutDoVerticalAlign(GapList);
    if ForNode.FCompSize.ContentWidth = MaxInt then ForNode.FCompSize.ContentWidth := NewWidth;
    if ForNode.FCompSize.ContentHeight = MaxInt then ForNode.FCompSize.ContentHeight := NewHeight;
    if TargetWidth =-1 then TargetWidth := NewWidth;
    if TargetHeight =-1 then TargetHeight := NewHeight;
    Inc(IterationCounter);
  until not NeedIteration;

  // adjust nodes after NewWidth of node is calculated for all sibling nodes
  ANode := ForNode;
//  if ForNode.CompStyle.Width.LengthType = cltPx then NewWidth := Round(ForNode.CompStyle.Width.Value);
  while Assigned(ANode) do begin
    cs := ANode.CompStyle;
    if (cs.Display in [cdtBlock, cdtFlex, cdtGrid]) and (cs.Width.LengthType in [cltUndefined, cltAuto]) and
      (cs.MaxWidth.LengthType = cltUndefined) and (cs.Float in [cftUndefined, cftNone]) and
      not (cs.Position in [cpAbsolute, cpFixed]) and not ANode.FLayoutRoot then begin // fix block alignment  (eg. first node is block and next is inline, and block width is not correct)
      ANode.FCompSize.MarginRect.Right := TargetWidth;
      ANode.FCompSize.ContentRect.Right := ANode.FCompSize.MarginRect.Right - ANode.CompSize.Margin.Right;
    end;
    if (cs.Position in [cpAbsolute, cpFixed]) and (ANode.FCompStyle.Display <> cdtNone) and
      (not (cs.Right.LengthType in [cltUndefined, cltAuto]) or not (cs.Bottom.LengthType in [cltUndefined, cltAuto]) or
       (cs.Left.LengthType = cltPercentage) or (cs.Top.LengthType = cltPercentage)) then begin
      // right/bottom and percent insets: size of container is known now (static position is kept)
      X := ANode.FCompSize.MarginRect.Left;
      Y := ANode.FCompSize.MarginRect.Top;
      ANode.PlaceAbsolute(TargetWidth, TargetHeight);
      if (cs.Left.LengthType in [cltUndefined, cltAuto]) and (cs.Right.LengthType in [cltUndefined, cltAuto]) then
        OffsetRect(ANode.FCompSize.MarginRect, X - ANode.FCompSize.MarginRect.Left, 0);
      if (cs.Top.LengthType in [cltUndefined, cltAuto]) and (cs.Bottom.LengthType in [cltUndefined, cltAuto]) then
        OffsetRect(ANode.FCompSize.MarginRect, 0, Y - ANode.FCompSize.MarginRect.Top);
      with ANode.FCompSize do
        ContentRect := Rect(MarginRect.Left + Margin.Left, MarginRect.Top + Margin.Top, MarginRect.Right - Margin.Right, MarginRect.Bottom - Margin.Bottom);
    end;
    if cs.Position = cpRelative then begin
      if cs.Left.LengthType in [cltUndefined, cltAuto] then X := -ANode.FCompSize.Position.Right else X := ANode.FCompSize.Position.Left;
      if cs.Top.LengthType in [cltUndefined, cltAuto] then Y := -ANode.FCompSize.Position.Bottom else Y := ANode.FCompSize.Position.Top;
      OffsetRect( ANode.FCompSize.MarginRect, X, Y);
      OffsetRect( ANode.FCompSize.ContentRect, X, Y);
    end;
    ANode := ANode.GetNext(ANode, False);
  end;
  GapList.Free;
end;

(*
  Calculate layout size based on target Rect
  Logic:
  - first go trought all nodes and find Width/Height/Margins for nodes with fixed or defined values CalcSize(Self, ARect.Width, ARect.Height);
  - next step is calculate real content rect and calculate remaining width/height based on chlidren width/height SetPosition(Self, ARect);
  - loop until all nodes have valid sizes
  - last is Controls alignment if AAlignControls is set
*)

procedure THtmlNode.LayoutTo(ALeft, ATop, AWidth, AHeight: Integer);
var
  TempWidth, TempHeight: Integer;
  Pass: Cardinal;
  Next: THtmlNode;
  CtrlNode: THtmlNode; // for align controls
  CtrlOldBounds, CtrlNewBounds: TRect;
  (*
    Adjust positions and set visible status based on parents nodes
  *)
  procedure UpdateTransforms(ANode: THtmlNode);
  var
    N: THtmlNode;
  begin
    ANode.ComputeTransform;
    ANode.UpdateScrollRange;
    N := ANode.FFirstChild;
    while Assigned(N) do begin
      UpdateTransforms(N);
      N := N.FNextSibling;
    end;
  end;
  // children of nodes with cached size are arranged for the last requested size
  procedure FixLayout(ANode: THtmlNode; APass: Cardinal);
  var
    K: TCSSLayoutKey;
  begin
    while Assigned(ANode) do begin
      if (ANode.FLayPass = APass) and not SameLayoutKey(ANode.FLayState, ANode.FLayWanted) then begin
        K := ANode.FLayWanted;
        CSSLayoutRecompute := ANode;
        try
          LayoutGetNodeSize(ANode, ANode.FLayWantedPW, ANode.FLayWantedPH, K.InFlex, K.FW, K.FH);
        finally
          CSSLayoutRecompute := nil;
        end;
      end;
      if ANode.FChildCount > 0 then FixLayout(ANode.FFirstChild, APass);
      ANode := ANode.FNextSibling;
    end;
  end;
  procedure AdjustPosition(ANode: THtmlNode; StartX, StartY: Integer; ParentVisible: Boolean);
  var
    Dx, Dy: Integer;
  begin
    while Assigned(ANode) do begin
      ANode.FVisible := (ANode.FCompStyle.Display <> cdtNone) and (ParentVisible);
      if ANode.FVisible then begin
        Dx := 0;
        Dy := 0;
        // margin: auto for block nodes (flex items are aligned by flex layout)
        if (ANode.ParentNode <> Nil) and (ANode.CompStyle.Display in [cdtBlock, cdtFlex, cdtGrid]) and
          not (ANode.ParentNode.CompStyle.Display in [cdtFlex, cdtInlineFlex]) and
          not (ANode.CompStyle.Position in [cpAbsolute, cpFixed]) and (ANode.CompStyle.Float in [cftUndefined, cftNone]) then begin
          if (ANode.CompStyle.Margin[csLeft].LengthType = cltAuto) and (ANode.CompStyle.Margin[csRight].LengthType = cltAuto) then
            Dx := (ANode.ParentNode.CompSize.RealContentWidth - ANode.CompSize.ContentWidth) div 2
          else if ANode.CompStyle.Margin[csLeft].LengthType = cltAuto then
            Dx := ANode.ParentNode.CompSize.RealContentWidth - ANode.CompSize.ContentWidth - ANode.CompSize.Margin.Right;
          if Dx < 0 then Dx := 0;
        end;
        OffsetRect(ANode.FCompSize.ContentRect, StartX + Dx, StartY + Dy);
        OffsetRect(ANode.FCompSize.MarginRect, StartX + Dx, StartY + Dy);
      end;
      if ANode.FChildCount > 0 then
        AdjustPosition(ANode.FFirstChild, ANode.FCompSize.ContentRect.Left + ANode.FCompSize.Padding.Left + ANode.FCompSize.Border.Left,
          ANode.FCompSize.ContentRect.Top + ANode.FCompSize.Padding.Top + ANode.FCompSize.Border.Top, ANode.FVisible);
      ANode := ANode.GetNext(ANode, False);
    end;
  end;
{
  var
    iFrequency, iTimerStart, iTimerEnd: Int64;
}
begin
//	QueryPerformanceFrequency(iFrequency);
//	QueryPerformanceCounter(iTimerStart);

//  Writeln(Awidth, ' - ' , AHeight);

  ResolveInheritedStyle;
  Self.CompSize.Margin := Rect(
    CalcLength(Self.CompStyle.Margin[csLeft], AWidth), CalcLength(Self.CompStyle.Margin[csTop], AWidth),
    CalcLength(Self.CompStyle.Margin[csRight], AWidth), CalcLength(Self.CompStyle.Margin[csBottom], AWidth));
  Self.CompSize.Padding := Rect(
    CalcLength(Self.CompStyle.Padding[csLeft], AWidth), CalcLength(Self.CompStyle.Padding[csTop], AWidth),
    CalcLength(Self.CompStyle.Padding[csRight], AWidth), CalcLength(Self.CompStyle.Padding[csBottom], AWidth));
  // auto margins are not supported for root node
  if Self.CompSize.Margin.Left = MaxInt then Self.CompSize.Margin.Left := 0;
  if Self.CompSize.Margin.Top = MaxInt then Self.CompSize.Margin.Top := 0;
  if Self.CompSize.Margin.Right = MaxInt then Self.CompSize.Margin.Right := 0;
  if Self.CompSize.Margin.Bottom = MaxInt then Self.CompSize.Margin.Bottom := 0;
  Self.CompSize.Border := Rect(BorderWidth(csLeft), BorderWidth(csTop), BorderWidth(csRight), BorderWidth(csBottom));

  // override "body" and ignore set width or height value
  FLayoutRoot := True;
  if AWidth = -1 then FLayoutWidth := -1
    else FLayoutWidth := Max(0, AWidth - Self.CompSize.LeftSpace - Self.CompSize.RightSpace);
  if AHeight = -1 then FLayoutHeight := -1
    else FLayoutHeight := Max(0, AHeight - Self.CompSize.TopSpace - Self.CompSize.BottomSpace);

//  if not AAlignControls then begin
  // only this node is laid out (not its next siblings)
  Next := FNextSibling;
  FNextSibling := nil;
  try
    Inc(CSSLayoutPass);
    Pass := CSSLayoutPass;
    LayoutCalcPosition(Self, AWidth, AHeight, TempWidth, TempHeight);
    FixLayout(Self, Pass);
    AdjustPosition(Self, ALeft, ATop, True);
  finally
    FNextSibling := Next;
  end;
  UpdateTransforms(Self);
  //QueryPerformanceCounter(iTimerEnd);
  //  WriteLn( FloatToStr( 1000 * ((iTimerEnd - iTimerStart) / ifrequency)));
//  if not AAlignControls then Exit;
end;

(*
  Align controls inside nodes
*)

procedure THtmlNode.AlignControlsTo(ALeft, ATop: Integer);
var
  DifX, DifY: Integer;
  ClipR: TRect;
  InView: Boolean;
  CtrlNode: THtmlNode;
  CtrlNewBounds,
  CtrlOldBounds: TRect;
begin
  {$ifdef fpc}
  if Self.RootNode.FParentControl <> Nil then begin
    DifX := Self.RootNode.FParentControl.Left;
    DifY := Self.RootNode.FParentControl.Top;
  end else{$endif} begin
    DifX := 0;
    DifY := 0;
  end;
  CtrlNode := Self;
  while Assigned(CtrlNode) do begin
//    CtrlNode.CompStyle.Changed := False;
    if Assigned(CtrlNode.AlignControl) then begin
      if not CtrlNode.FVisible then begin    // hide assigned control if owner node is invisible
        if CtrlNode.AlignControl.Visible then begin
          CtrlNode.FAlignControlWasHidden := True;
          CtrlNode.AlignControl.Visible := False;
        end
      end else begin
        if CtrlNode.FAlignControlWasHidden then begin
          CtrlNode.FAlignControlWasHidden := False;
          CtrlNode.AlignControl.Visible := True;
        end;
      end;
      {$ifdef fpc}
      CtrlOldBounds := CtrlNode.AlignControl.BoundsRect;
      {$endif}
      CtrlNewBounds := Rect(
        CtrlNode.FCompSize.ContentRect.Left + CtrlNode.FCompSize.Border.Left + CtrlNode.FCompSize.Padding.Left,
        CtrlNode.FCompSize.ContentRect.Top  + CtrlNode.FCompSize.Padding.Top + CtrlNode.FCompSize.Border.Top,
        CtrlNode.FCompSize.ContentRect.Right - CtrlNode.FCompSize.Border.Right - CtrlNode.FCompSize.Padding.Right,
        CtrlNode.FCompSize.ContentRect.Bottom - CtrlNode.FCompSize.Border.Bottom - CtrlNode.FCompSize.Padding.Bottom
      );
      CtrlNewBounds := CtrlNode.TransformedBounds(CtrlNewBounds);   // controls can be moved and scaled, not rotated
      // control can't be clipped: it is hidden when it is not whole in visible area (scrolled content)
      ClipR := CtrlNode.ScreenClipRect;
      InView := (CtrlNewBounds.Left >= ClipR.Left) and (CtrlNewBounds.Top >= ClipR.Top) and
        (CtrlNewBounds.Right <= ClipR.Right) and (CtrlNewBounds.Bottom <= ClipR.Bottom);
      if CtrlNode.FVisible and not InView and CtrlNode.AlignControl.Visible then begin
        CtrlNode.FAlignControlWasHidden := True;
        CtrlNode.AlignControl.Visible := False;
      end else
      if CtrlNode.FVisible and InView and CtrlNode.FAlignControlWasHidden then begin
        CtrlNode.FAlignControlWasHidden := False;
        CtrlNode.AlignControl.Visible := True;
      end;
      OffsetRect(CtrlNewBounds, DifX, DifY);

      if (CtrlNode.AlignControl.Parent <> nil) and (not CompareRect(@CtrlNewBounds,@CtrlOldBounds)) then begin
        CtrlNode.AlignControl.BringToFront;   // control must be above painted node
			  CtrlNode.AlignControl.SetBounds(
				  CtrlNewBounds.Left,
				  CtrlNewBounds.Top,
				  CtrlNewBounds.Right - CtrlNewBounds.Left,
				  CtrlNewBounds.Bottom - CtrlNewBounds.Top
			  );
      end;
    end;
    CtrlNode := CtrlNode.GetNext(CtrlNode, True);
  end;
end;

(*
  Get Last node at position with OnClick
*)
(*
  Top node at position (last painted). Clickable: nearest node with OnClick from top node up (like event
  bubbling in DOM), so a node covered by another one (dialog, popup) doesn't get the click.
*)
function THtmlNode.NodeAtPosition(APos: TPoint; AClickable: Boolean): THtmlNode;
  procedure Search(AParent: THtmlNode);
  var
    Children: THtmlNodeArray;
    I: Integer;
  begin
    Children := AParent.PaintOrder;
    for I := 0 to High(Children) do
      if Children[I].FVisible then begin
        if Children[I].HitTest(APos) then Result := Children[I];   // last painted is on top
        Search(Children[I]);
      end;
  end;
begin
  Result := Nil;
  if not FVisible then Exit;
  if HitTest(APos) then Result := Self;
  Search(Self);
  if AClickable then
    while Assigned(Result) and not Assigned(Result.FOnClick) do
      if Result = Self then Result := nil else Result := Result.ParentNode;
end;

(*
  Point is inside of node (border box), used for mouse events, transformations of node and parents are applied
*)
function THtmlNode.HitTest(const APos: TPoint): Boolean;
var
  P: TPointF;
  InClip: Boolean;
  N: THtmlNode;
begin
  N := Self;
  while Assigned(N) do begin     // pointer-events: none is inherited
    if N.FCompStyle.PointerEventsNone then Exit(False);
    N := N.ParentNode;
  end;
  P := ScreenToLayoutClip(PointF(APos.X + 0.5, APos.Y + 0.5), InClip);
  Result := InClip and (P.x >= FCompSize.ContentRect.Left) and (P.x < FCompSize.ContentRect.Right) and
    (P.y >= FCompSize.ContentRect.Top) and (P.y < FCompSize.ContentRect.Bottom);
end;

function THtmlNode.GetAttribute(const AName: String): String;
begin
  if Assigned(FAttributes) then Result := FAttributes.Values[LowerCase(AName)] else Result := '';
end;

procedure THtmlNode.SetAttribute(const AName, AValue: String);
begin
  if FAttributes = nil then FAttributes := TStringList.Create;
  FAttributes.Values[LowerCase(AName)] := AValue;
end;

function THtmlNode.SetInline(AValue: String): THtmlNode;
begin
  Result := Self;
  InlineStyle := AValue;
end;

function THtmlNode.SetId(AValue: String): THtmlNode;
begin
  Result := Self;
  FId := AValue;
end;

function THtmlNode.SetHover(AValue: String): THtmlNode;
begin
  Result := Self;
  HoverStyle := AValue;
end;

function THtmlNode.SetOnClick(AValue: TNotifyEvent): THtmlNode;
begin
  Result := Self;
  FOnClick := AValue;
end;

(*
  Insert child node before ARefNode (child of this node), node is moved when it is in a tree
*)
function THtmlNode.InsertBefore(ANode, ARefNode: THtmlNode): THtmlNode;
begin
  Result := Self;
  if (ANode = nil) or (ANode = ARefNode) then Exit;
  AddNode(ANode);                        // appended (moved from old parent)
  if (ARefNode = nil) or (ARefNode.ParentNode <> Self) then Exit;
  // move from end before ARefNode
  FLastNode := ANode.FPrevSibling;
  FLastNode.FNextSibling := nil;
  ANode.FPrevSibling := ARefNode.FPrevSibling;
  ANode.FNextSibling := ARefNode;
  if Assigned(ARefNode.FPrevSibling) then ARefNode.FPrevSibling.FNextSibling := ANode
  else begin
    FFirstChild := ANode;
    FFirstNode := ANode;
  end;
  ARefNode.FPrevSibling := ANode;
  if Assigned(RootNode.StyleSheet) or Assigned(CSSUtilityResolver) then begin   // :first-child, sibling utilities
    ApplySubtree(ANode);
    ApplyStyleForNode(ARefNode);
    if Assigned(FLastNode) then ApplyStyleForNode(FLastNode);
  end;
end;

function THtmlNode.AppendTo(AParentNode: THtmlNode): THtmlNode;
begin
  Result := Self;
  AParentNode.AddNode(Self);
end;


function THtmlNode.SetText(const AValue: String): THtmlNode;
begin
  Result := Self;
  FText := AValue;
end;

function THtmlNode.SetTagStr(AValue: String): THtmlNode;
begin
  TagStr := AValue;
  Result := Self;
end;

function THtmlNode.Clear: THtmlNode;
begin
  Result := Self;
  if Assigned(FFirstChild) and Assigned(RootNode) and (RootNode <> Self) then RootNode.NoteChanged(Self);
  while Assigned(FFirstChild) do
    FFirstChild.Free;   // children is detached (removed from list) in destructor
  Self.FChildCount := 0;
  Self.FLastNode := Nil;
  Self.FFirstNode := Nil;
end;

function THtmlNode.Delete(ANode: THtmlNode): THtmlNode;
begin
  Result := Self;
  if (not Assigned(ANode)) or (ANode = Self) or (ANode = RootNode) then Exit;
  ANode.Detach;
  ANode.Free;  // destructor removes all childrens
  Changed;
end;

var
  CSSUpdateCount: Integer = 0;

procedure CSSBeginUpdate;
begin
  Inc(CSSUpdateCount);
end;

var
  CSSPendingChanged: TList;      // controls changed during CSSBeginUpdate (laid out once in CSSEndUpdate)

procedure CSSEndUpdate;
var
  L: TList;
  I: Integer;
  C: ICSSControl;
begin
  if CSSUpdateCount > 0 then Dec(CSSUpdateCount);
  if (CSSUpdateCount > 0) or (CSSPendingChanged = nil) then Exit;
  L := CSSPendingChanged;
  CSSPendingChanged := nil;
  try
    for I := 0 to L.Count - 1 do
      if TControl(L[I]).GetInterface(StringToGUID(HTMLInterface), C) then C.Changed;
  finally
    L.Free;
  end;
end;

function CSSUpdatePending(AControl: TControl): Boolean;
begin
  Result := CSSUpdateCount > 0;
  if not Result then Exit;
  if CSSPendingChanged = nil then CSSPendingChanged := TList.Create;
  if CSSPendingChanged.IndexOf(AControl) < 0 then CSSPendingChanged.Add(AControl);
end;

procedure CSSUpdateForget(AControl: TControl);
begin
  if Assigned(CSSPendingChanged) then CSSPendingChanged.Remove(AControl);
end;

(*
  Repaint of changed area: root remembers old area of changed and removed nodes (at the time of change), changed
  nodes are marked, after layout TCSSShape paints old area, new area of marked nodes and areas of moved nodes
*)
procedure UnionDirty(var ADirty: TRect; const ARect: TRect);
begin
  if ARect.IsEmpty then Exit;
  if ADirty.IsEmpty then ADirty := ARect else ADirty := TRect.Union(ADirty, ARect);
end;

procedure THtmlNode.NoteChanged(ANode: THtmlNode);
begin
  FHasChanges := True;
  if FChangedAll then Exit;
  if ANode = Self then begin       // whole tree (eg. styles applied again)
    FChangedAll := True;
    Exit;
  end;
  ANode.FChangedMark := True;
  UnionDirty(FDirtyOld, ANode.SubtreePaintedRect);
end;

function THtmlNode.SubtreePaintedRect: TRect;
var
  N: THtmlNode;
begin
  Result := PaintedRect;
  N := FFirstChild;
  while Assigned(N) do begin
    UnionDirty(Result, N.SubtreePaintedRect);
    N := N.FNextSibling;
  end;
end;

function THtmlNode.PaintedRects: TCSSRectArray;
var
  Count: Integer;
  procedure Add(ANode: THtmlNode);
  begin
    while Assigned(ANode) do begin
      if Count >= Length(Result) then SetLength(Result, Count * 2 + 64);
      Result[Count] := ANode.PaintedRect;
      Inc(Count);
      Add(ANode.FFirstChild);
      ANode := ANode.FNextSibling;
    end;
  end;
begin
  Result := nil;
  Count := 0;
  Result := nil;
  SetLength(Result, 64);
  Result[0] := PaintedRect;
  Count := 1;
  Add(FFirstChild);
  SetLength(Result, Count);
end;

function THtmlNode.TakeDirtyRect(const AOldRects: TCSSRectArray): TRect;
var
  I: Integer;
  procedure Visit(ANode: THtmlNode; AInChanged: Boolean);
  var
    R: TRect;
    Changed: Boolean;
  begin
    while Assigned(ANode) do begin
      R := ANode.PaintedRect;
      Changed := AInChanged or ANode.FChangedMark;    // descendants of changed node can change too (inherited styles)
      ANode.FChangedMark := False;
      if Changed then UnionDirty(Result, R);
      if I <= High(AOldRects) then begin           // moved or resized node (tree is the same as in AOldRects)
        if AOldRects[I] <> R then begin
          UnionDirty(Result, AOldRects[I]);
          UnionDirty(Result, R);
        end;
      end else
        UnionDirty(Result, R);
      Inc(I);
      Visit(ANode.FFirstChild, Changed);
      ANode := ANode.FNextSibling;
    end;
  end;
  procedure ClearMarks(ANode: THtmlNode);
  begin
    while Assigned(ANode) do begin
      ANode.FChangedMark := False;
      ClearMarks(ANode.FFirstChild);
      ANode := ANode.FNextSibling;
    end;
  end;
begin
  Result := FDirtyOld;
  I := 1;
  if AOldRects = nil then begin      // only changes are cleared (whole shape is painted)
    ClearMarks(FFirstChild);
    Result := Rect(0, 0, 0, 0);
  end else begin
    if AOldRects[0] <> PaintedRect then Result := PaintedRect;
    Visit(FFirstChild, False);
  end;
  FDirtyOld := Rect(0, 0, 0, 0);
  FHasChanges := False;
  FChangedAll := False;
end;

function THtmlNode.PaintedRect: TRect;
begin
  Result := FCompSize.ContentRect;
  if not FVisible or Result.IsEmpty then Exit(Rect(0, 0, 0, 0));
  if FCompStyle.BoxShadow <> '' then InflateRect(Result, 60, 60) else InflateRect(Result, 2, 2);
  Result := TRect.Intersect(TransformedBounds(Result), ScreenClipRect);    // scrolled out part is not visible
end;

procedure THtmlNode.Changed;
var
  I: ICSSControl;
begin
  Inc(CSSPaintGeneration);
  if Assigned(RootNode) and (RootNode <> Self) then RootNode.NoteChanged(Self);
  if CSSUpdateCount > 0 then begin      // CSSBeginUpdate: layout once at the end
    if Assigned(RootNode) and Assigned(RootNode.ParentControl) then begin
      if CSSPendingChanged = nil then CSSPendingChanged := TList.Create;
      if CSSPendingChanged.IndexOf(RootNode.ParentControl) < 0 then CSSPendingChanged.Add(RootNode.ParentControl);
    end;
    Exit;
  end;
  if Assigned(RootNode) and Assigned(RootNode.ParentControl) then begin
    if RootNode.ParentControl.GetInterface(StringToGUID(HTMLInterface), I) then
      I.Changed;
  end;
end;

(*
  Count nodes (siblings and their descendants) starting from ANode
*)
function THtmlNode.CountNodes(ANode: THtmlNode): Integer;
begin
  Result := 0;
  while Assigned(ANode) do begin
    Inc(Result, 1 + CountNodes(ANode.FFirstChild));
    ANode := ANode.FNextSibling;
  end;
end;

(*
  Remove node from parent (node is not freed)
*)
procedure THtmlNode.Detach;
  procedure SetRoot(ForNode: THtmlNode; ARoot: THtmlNode);
  begin
    while Assigned(ForNode) do begin
      ForNode.RootNode := ARoot;
      if ForNode.FChildCount > 0 then SetRoot(ForNode.FFirstChild, ARoot);
      ForNode := ForNode.FNextSibling;
    end;
  end;
begin
  if not Assigned(ParentNode) then Exit;
  if Assigned(RootNode) and (RootNode <> Self) then begin
    RootNode.NoteChanged(Self);      // old area of removed node is painted again
    Dec(RootNode.FTotalCount, 1 + CountNodes(FFirstChild));
  end;
  if Assigned(FPrevSibling) then FPrevSibling.FNextSibling := FNextSibling;
  if Assigned(FNextSibling) then FNextSibling.FPrevSibling := FPrevSibling;
  if ParentNode.FFirstChild = Self then ParentNode.FFirstChild := FNextSibling;
  if ParentNode.FFirstNode = Self then ParentNode.FFirstNode := FNextSibling;
  if ParentNode.FLastNode = Self then ParentNode.FLastNode := FPrevSibling;
  Dec(ParentNode.FChildCount);
  FPrevSibling := nil;
  FNextSibling := nil;
  ParentNode := nil;
  RootNode := Self;
  SetRoot(FFirstChild, Self);
end;

function THtmlNode.AddNode(ANode: THtmlNode): THtmlNode;
  procedure SetMyParent(ForNode: THtmlNode);
  begin
    while Assigned(ForNode) do begin
      ForNode.RootNode := Self.RootNode;
      if ForNode.ChildCount > 0 then SetMyParent(ForNode.FFirstChild);
      ForNode := ForNode.FNextSibling;
    end;
  end;
var
  P: THtmlNode;
begin
  Result := Self;
  if RootNode = Nil then
    Raise Exception.Create('There is no root node!');
  if not Assigned(ANode) then Exit;
  P := Self;
  while Assigned(P) do begin
    if P = ANode then
      Raise Exception.Create('Can''t add self or parent node as children!');
    P := P.ParentNode;
  end;
  ANode.Detach;   // node can be in another tree
  ANode.ParentNode := Self;
  ANode.FLayoutRoot := False;
  ANode.RootNode := Self.RootNode;
  SetMyParent(ANode.FFirstChild);
  if FFirstNode = Nil then FFirstNode := ANode;
  if FFirstChild = Nil then FFirstChild := ANode;
  if FLastNode <> Nil then FLastNode.FNextSibling := ANode;
  ANode.FPrevSibling := FLastNode;
  ANode.FNextSibling := nil;
  FLastNode := ANode;
  Inc(Self.FChildCount);
  Inc(RootNode.FTotalCount, 1 + CountNodes(ANode.FFirstChild));
  // styles depends on position in tree (stylesheet of root node, :first-child, :last-child ...)
  if Assigned(RootNode.StyleSheet) or Assigned(CSSUtilityResolver) then begin
    ApplySubtree(ANode);
    // previous sibling is not last child now: only stylesheet rules (:last-child) and last: utilities depend on it
    if Assigned(ANode.FPrevSibling) and (Assigned(RootNode.StyleSheet) or (Pos('last:', ANode.FPrevSibling.FClassList.Name) > 0)) then
      ApplyStyleForNode(ANode.FPrevSibling);
  end;
  RootNode.NoteChanged(ANode);
end;

(*
  Apply styles to node and all its descendants
*)
procedure THtmlNode.ApplySubtree(ANode: THtmlNode);
var
  N: THtmlNode;
begin
  ApplyStyleForNode(ANode);
  N := ANode.FFirstChild;
  while Assigned(N) do begin
    ApplySubtree(N);
    N := N.FNextSibling;
  end;
end;

function THtmlNode.GetNext(ANode: THtmlNode; GoAboveChildren: Boolean): THtmlNode;
begin
  Result := ANode;
  if not Assigned(Result) then exit;
  if (GoAboveChildren) then begin
    if Assigned(Result.FFirstChild) then
      Result := Result.FFirstChild
    else begin
      repeat
        if Result = Nil then Break;
        if Assigned(Result.FNextSibling) then begin
          Result := Result.FNextSibling;
          Break;
        end else begin
          if Result.ParentNode <> RootNode then
            Result := Result.ParentNode
          else begin
            Result := Nil;
            Break;
          end;
        end;
      until False;
    end;
  end else begin
    Result := ANode.FNextSibling;
  end;
end;

(*
  Find all nodes (self and descendants) with class AName
*)
function THtmlNode.GetElementsByClassName(AName: String): THtmlNodeArray;
  procedure Search(ANode: THtmlNode);
  begin
    while Assigned(ANode) do begin
      if ANode.ClassList.Contains(AName) then begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := ANode;
      end;
      if ANode.FChildCount > 0 then Search(ANode.FFirstChild);
      ANode := ANode.FNextSibling;
    end;
  end;
begin
  Result := nil;
  if ClassList.Contains(AName) then begin
    SetLength(Result, 1);
    Result[0] := Self;
  end;
  Search(FFirstChild);
end;

(*
  Find first node (self or descendant) with Id
*)
function THtmlNode.GetElementById(const AId: String): THtmlNode;
var
  Node: THtmlNode;
begin
  Result := nil;
  if FId = AId then Exit(Self);
  Node := FFirstChild;
  while Assigned(Node) do begin
    Result := Node.GetElementById(AId);
    if Assigned(Result) then Exit;
    Node := Node.FNextSibling;
  end;
end;

(*
  Get property value from inline style
*)
function THtmlNode.GetStyleValue(AName: String): String;
var
  Names, Values: TStringList;
  I: Integer;
begin
  Result := '';
  Names := TStringList.Create;
  Values := TStringList.Create;
  try
    SplitDeclarations(FInlineStyle, Names, Values);
    for I := Names.Count - 1 downto 0 do
      if Names[I] = LowerCase(Trim(AName)) then Exit(Values[I]);
  finally
    Names.Free;
    Values.Free;
  end;
end;

procedure THtmlNode.SetHovered(AValue: Boolean);
begin
  if FHovered = AValue then Exit;
  FHovered := AValue;
end;

procedure THtmlNode.SetHoverStyle(AValue: String);
begin
  if FHoverStyle = AValue then Exit;
  FHoverStyle := AValue;
end;

(*
  Setup inline style by user. Same like in html document:   <div style="THIS PART IS AVALUE">
*)
procedure THtmlNode.SetInlineStyle(AValue: String);
begin
  if FInlineStyle = AValue then Exit;
  FInlineStyle := AValue;
  ApplyStyleForNode(Self);   // stylesheet + inline style
  Changed;

{  if RootNode.FParentControl <> Nil then begin
    RootNode.FParentControl.InvalidatePreferredSize;
    RootNode.FParentControl.Invalidate;
  end;}
end;

initialization
begin
  InitCSSColors;
end;

finalization
begin
  CSSColorList.Free;
  CSSCornerCache.Free;
  CSSPaintTemp.Free;
  CSSShadowCache.Free;
  CSSImageCache.Free;
  CSSAnimNodes.Free;
  CSSUtilityCache.Free;
  CSSFontFamilyCache.Free;
  {$ifndef fmx}
  CSSMeasureBitmap.Free;
  {$endif}
end;

end.
