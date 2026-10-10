(*
  Tailwind CSS like utility classes for csscontrols
  Author: Pavol Stugel (pstugel@gmail.com)

  Usage:
    CSSTailwindEnable;      // once, eg. in initialization of main form unit
    Body.AddNode(HTMLDiv('').SetClass('flex items-center gap-2 p-4 bg-blue-500 hover:bg-blue-600 text-white rounded-lg'));

  Supported (subset of Tailwind CSS v3):
    layout:     block inline-block inline flex inline-flex hidden, static relative absolute fixed sticky,
                inset-*, top-*, right-*, bottom-*, left-*, float-*, overflow-*, box-border box-content
    flexbox:    flex-row(-reverse) flex-col(-reverse) flex-wrap(-reverse) flex-nowrap flex-1 flex-auto flex-initial
                flex-none grow(-0) shrink(-0) basis-* order-* justify-* items-* self-* gap(-x,-y)-*
    spacing:    p-* px-* py-* pt-* pr-* pb-* pl-* m-* mx-* my-* mt-* mr-* mb-* ml-* (negative values, auto)
    sizing:     w-* h-* size-* min-w-* min-h-* max-w-* max-h-* (spacing scale, fractions, full, screen, auto, px)
    typography: text-xs..text-9xl text-left/center/right/justify text-{color} font-thin..font-black
                font-sans/serif/mono italic not-italic underline line-through no-underline
                whitespace-nowrap whitespace-normal truncate
    background: bg-{color} (see gradients and images below)
    borders:    border(-x,-y,-t,-r,-b,-l)(-0,-2,-4,-8) border-{color} border-solid/dashed/dotted/none
                rounded(-t,-r,-b,-l,-tl,-tr,-br,-bl)(-none,-sm,-md,-lg,-xl,-2xl,-3xl,-full)
    shadows:    shadow-sm shadow shadow-md shadow-lg shadow-xl shadow-2xl shadow-none shadow-{color}
    other:      cursor-*
    values:     arbitrary values eg. w-[200px] bg-[#ff8800] p-[3px] text-[13px]
    variants:   hover: active: first: last: odd: even: group-hover: sm: md: lg: xl: 2xl: (see cssbase.pas)

    gradients:  bg-gradient-to-{t,tr,r,br,b,bl,l,tl} from-{color} via-{color} to-{color}
    images:     bg-[url(file.png)] bg-none bg-cover bg-contain bg-auto bg-center bg-top ... bg-no-repeat bg-repeat
    opacity:    color modifiers eg. bg-black/50 text-white/70 border-slate-900/10

  Not supported: inset shadows (shadow-inner), transitions, transforms, grid, space-x/y, dark mode.
*)
unit csstailwind;

{$ifdef fpc}
  {$mode objfpc}{$H+}
{$endif}

interface

uses
  Classes, SysUtils, Math, Graphics, cssbase;

procedure CSSTailwindEnable(ABorderBox: Boolean = True);
procedure CSSTailwindDisable;
function TailwindResolve(const AClassName: String; out ADeclarations: String; out AOrder: Integer): Boolean;
function TailwindColor(const AName: String; out AColor: String): Boolean;

implementation

const
  // Tailwind CSS v3 color palette, Copyright (c) Tailwind Labs, Inc., MIT License
  // https://github.com/tailwindlabs/tailwindcss/blob/v3.4.17/src/public/colors.js
  TW_COLORS: array[0..241] of record N, V: String; end = (
    (N: 'slate-50'; V: '#f8fafc'),
    (N: 'slate-100'; V: '#f1f5f9'),
    (N: 'slate-200'; V: '#e2e8f0'),
    (N: 'slate-300'; V: '#cbd5e1'),
    (N: 'slate-400'; V: '#94a3b8'),
    (N: 'slate-500'; V: '#64748b'),
    (N: 'slate-600'; V: '#475569'),
    (N: 'slate-700'; V: '#334155'),
    (N: 'slate-800'; V: '#1e293b'),
    (N: 'slate-900'; V: '#0f172a'),
    (N: 'slate-950'; V: '#020617'),
    (N: 'gray-50'; V: '#f9fafb'),
    (N: 'gray-100'; V: '#f3f4f6'),
    (N: 'gray-200'; V: '#e5e7eb'),
    (N: 'gray-300'; V: '#d1d5db'),
    (N: 'gray-400'; V: '#9ca3af'),
    (N: 'gray-500'; V: '#6b7280'),
    (N: 'gray-600'; V: '#4b5563'),
    (N: 'gray-700'; V: '#374151'),
    (N: 'gray-800'; V: '#1f2937'),
    (N: 'gray-900'; V: '#111827'),
    (N: 'gray-950'; V: '#030712'),
    (N: 'zinc-50'; V: '#fafafa'),
    (N: 'zinc-100'; V: '#f4f4f5'),
    (N: 'zinc-200'; V: '#e4e4e7'),
    (N: 'zinc-300'; V: '#d4d4d8'),
    (N: 'zinc-400'; V: '#a1a1aa'),
    (N: 'zinc-500'; V: '#71717a'),
    (N: 'zinc-600'; V: '#52525b'),
    (N: 'zinc-700'; V: '#3f3f46'),
    (N: 'zinc-800'; V: '#27272a'),
    (N: 'zinc-900'; V: '#18181b'),
    (N: 'zinc-950'; V: '#09090b'),
    (N: 'neutral-50'; V: '#fafafa'),
    (N: 'neutral-100'; V: '#f5f5f5'),
    (N: 'neutral-200'; V: '#e5e5e5'),
    (N: 'neutral-300'; V: '#d4d4d4'),
    (N: 'neutral-400'; V: '#a3a3a3'),
    (N: 'neutral-500'; V: '#737373'),
    (N: 'neutral-600'; V: '#525252'),
    (N: 'neutral-700'; V: '#404040'),
    (N: 'neutral-800'; V: '#262626'),
    (N: 'neutral-900'; V: '#171717'),
    (N: 'neutral-950'; V: '#0a0a0a'),
    (N: 'stone-50'; V: '#fafaf9'),
    (N: 'stone-100'; V: '#f5f5f4'),
    (N: 'stone-200'; V: '#e7e5e4'),
    (N: 'stone-300'; V: '#d6d3d1'),
    (N: 'stone-400'; V: '#a8a29e'),
    (N: 'stone-500'; V: '#78716c'),
    (N: 'stone-600'; V: '#57534e'),
    (N: 'stone-700'; V: '#44403c'),
    (N: 'stone-800'; V: '#292524'),
    (N: 'stone-900'; V: '#1c1917'),
    (N: 'stone-950'; V: '#0c0a09'),
    (N: 'red-50'; V: '#fef2f2'),
    (N: 'red-100'; V: '#fee2e2'),
    (N: 'red-200'; V: '#fecaca'),
    (N: 'red-300'; V: '#fca5a5'),
    (N: 'red-400'; V: '#f87171'),
    (N: 'red-500'; V: '#ef4444'),
    (N: 'red-600'; V: '#dc2626'),
    (N: 'red-700'; V: '#b91c1c'),
    (N: 'red-800'; V: '#991b1b'),
    (N: 'red-900'; V: '#7f1d1d'),
    (N: 'red-950'; V: '#450a0a'),
    (N: 'orange-50'; V: '#fff7ed'),
    (N: 'orange-100'; V: '#ffedd5'),
    (N: 'orange-200'; V: '#fed7aa'),
    (N: 'orange-300'; V: '#fdba74'),
    (N: 'orange-400'; V: '#fb923c'),
    (N: 'orange-500'; V: '#f97316'),
    (N: 'orange-600'; V: '#ea580c'),
    (N: 'orange-700'; V: '#c2410c'),
    (N: 'orange-800'; V: '#9a3412'),
    (N: 'orange-900'; V: '#7c2d12'),
    (N: 'orange-950'; V: '#431407'),
    (N: 'amber-50'; V: '#fffbeb'),
    (N: 'amber-100'; V: '#fef3c7'),
    (N: 'amber-200'; V: '#fde68a'),
    (N: 'amber-300'; V: '#fcd34d'),
    (N: 'amber-400'; V: '#fbbf24'),
    (N: 'amber-500'; V: '#f59e0b'),
    (N: 'amber-600'; V: '#d97706'),
    (N: 'amber-700'; V: '#b45309'),
    (N: 'amber-800'; V: '#92400e'),
    (N: 'amber-900'; V: '#78350f'),
    (N: 'amber-950'; V: '#451a03'),
    (N: 'yellow-50'; V: '#fefce8'),
    (N: 'yellow-100'; V: '#fef9c3'),
    (N: 'yellow-200'; V: '#fef08a'),
    (N: 'yellow-300'; V: '#fde047'),
    (N: 'yellow-400'; V: '#facc15'),
    (N: 'yellow-500'; V: '#eab308'),
    (N: 'yellow-600'; V: '#ca8a04'),
    (N: 'yellow-700'; V: '#a16207'),
    (N: 'yellow-800'; V: '#854d0e'),
    (N: 'yellow-900'; V: '#713f12'),
    (N: 'yellow-950'; V: '#422006'),
    (N: 'lime-50'; V: '#f7fee7'),
    (N: 'lime-100'; V: '#ecfccb'),
    (N: 'lime-200'; V: '#d9f99d'),
    (N: 'lime-300'; V: '#bef264'),
    (N: 'lime-400'; V: '#a3e635'),
    (N: 'lime-500'; V: '#84cc16'),
    (N: 'lime-600'; V: '#65a30d'),
    (N: 'lime-700'; V: '#4d7c0f'),
    (N: 'lime-800'; V: '#3f6212'),
    (N: 'lime-900'; V: '#365314'),
    (N: 'lime-950'; V: '#1a2e05'),
    (N: 'green-50'; V: '#f0fdf4'),
    (N: 'green-100'; V: '#dcfce7'),
    (N: 'green-200'; V: '#bbf7d0'),
    (N: 'green-300'; V: '#86efac'),
    (N: 'green-400'; V: '#4ade80'),
    (N: 'green-500'; V: '#22c55e'),
    (N: 'green-600'; V: '#16a34a'),
    (N: 'green-700'; V: '#15803d'),
    (N: 'green-800'; V: '#166534'),
    (N: 'green-900'; V: '#14532d'),
    (N: 'green-950'; V: '#052e16'),
    (N: 'emerald-50'; V: '#ecfdf5'),
    (N: 'emerald-100'; V: '#d1fae5'),
    (N: 'emerald-200'; V: '#a7f3d0'),
    (N: 'emerald-300'; V: '#6ee7b7'),
    (N: 'emerald-400'; V: '#34d399'),
    (N: 'emerald-500'; V: '#10b981'),
    (N: 'emerald-600'; V: '#059669'),
    (N: 'emerald-700'; V: '#047857'),
    (N: 'emerald-800'; V: '#065f46'),
    (N: 'emerald-900'; V: '#064e3b'),
    (N: 'emerald-950'; V: '#022c22'),
    (N: 'teal-50'; V: '#f0fdfa'),
    (N: 'teal-100'; V: '#ccfbf1'),
    (N: 'teal-200'; V: '#99f6e4'),
    (N: 'teal-300'; V: '#5eead4'),
    (N: 'teal-400'; V: '#2dd4bf'),
    (N: 'teal-500'; V: '#14b8a6'),
    (N: 'teal-600'; V: '#0d9488'),
    (N: 'teal-700'; V: '#0f766e'),
    (N: 'teal-800'; V: '#115e59'),
    (N: 'teal-900'; V: '#134e4a'),
    (N: 'teal-950'; V: '#042f2e'),
    (N: 'cyan-50'; V: '#ecfeff'),
    (N: 'cyan-100'; V: '#cffafe'),
    (N: 'cyan-200'; V: '#a5f3fc'),
    (N: 'cyan-300'; V: '#67e8f9'),
    (N: 'cyan-400'; V: '#22d3ee'),
    (N: 'cyan-500'; V: '#06b6d4'),
    (N: 'cyan-600'; V: '#0891b2'),
    (N: 'cyan-700'; V: '#0e7490'),
    (N: 'cyan-800'; V: '#155e75'),
    (N: 'cyan-900'; V: '#164e63'),
    (N: 'cyan-950'; V: '#083344'),
    (N: 'sky-50'; V: '#f0f9ff'),
    (N: 'sky-100'; V: '#e0f2fe'),
    (N: 'sky-200'; V: '#bae6fd'),
    (N: 'sky-300'; V: '#7dd3fc'),
    (N: 'sky-400'; V: '#38bdf8'),
    (N: 'sky-500'; V: '#0ea5e9'),
    (N: 'sky-600'; V: '#0284c7'),
    (N: 'sky-700'; V: '#0369a1'),
    (N: 'sky-800'; V: '#075985'),
    (N: 'sky-900'; V: '#0c4a6e'),
    (N: 'sky-950'; V: '#082f49'),
    (N: 'blue-50'; V: '#eff6ff'),
    (N: 'blue-100'; V: '#dbeafe'),
    (N: 'blue-200'; V: '#bfdbfe'),
    (N: 'blue-300'; V: '#93c5fd'),
    (N: 'blue-400'; V: '#60a5fa'),
    (N: 'blue-500'; V: '#3b82f6'),
    (N: 'blue-600'; V: '#2563eb'),
    (N: 'blue-700'; V: '#1d4ed8'),
    (N: 'blue-800'; V: '#1e40af'),
    (N: 'blue-900'; V: '#1e3a8a'),
    (N: 'blue-950'; V: '#172554'),
    (N: 'indigo-50'; V: '#eef2ff'),
    (N: 'indigo-100'; V: '#e0e7ff'),
    (N: 'indigo-200'; V: '#c7d2fe'),
    (N: 'indigo-300'; V: '#a5b4fc'),
    (N: 'indigo-400'; V: '#818cf8'),
    (N: 'indigo-500'; V: '#6366f1'),
    (N: 'indigo-600'; V: '#4f46e5'),
    (N: 'indigo-700'; V: '#4338ca'),
    (N: 'indigo-800'; V: '#3730a3'),
    (N: 'indigo-900'; V: '#312e81'),
    (N: 'indigo-950'; V: '#1e1b4b'),
    (N: 'violet-50'; V: '#f5f3ff'),
    (N: 'violet-100'; V: '#ede9fe'),
    (N: 'violet-200'; V: '#ddd6fe'),
    (N: 'violet-300'; V: '#c4b5fd'),
    (N: 'violet-400'; V: '#a78bfa'),
    (N: 'violet-500'; V: '#8b5cf6'),
    (N: 'violet-600'; V: '#7c3aed'),
    (N: 'violet-700'; V: '#6d28d9'),
    (N: 'violet-800'; V: '#5b21b6'),
    (N: 'violet-900'; V: '#4c1d95'),
    (N: 'violet-950'; V: '#2e1065'),
    (N: 'purple-50'; V: '#faf5ff'),
    (N: 'purple-100'; V: '#f3e8ff'),
    (N: 'purple-200'; V: '#e9d5ff'),
    (N: 'purple-300'; V: '#d8b4fe'),
    (N: 'purple-400'; V: '#c084fc'),
    (N: 'purple-500'; V: '#a855f7'),
    (N: 'purple-600'; V: '#9333ea'),
    (N: 'purple-700'; V: '#7e22ce'),
    (N: 'purple-800'; V: '#6b21a8'),
    (N: 'purple-900'; V: '#581c87'),
    (N: 'purple-950'; V: '#3b0764'),
    (N: 'fuchsia-50'; V: '#fdf4ff'),
    (N: 'fuchsia-100'; V: '#fae8ff'),
    (N: 'fuchsia-200'; V: '#f5d0fe'),
    (N: 'fuchsia-300'; V: '#f0abfc'),
    (N: 'fuchsia-400'; V: '#e879f9'),
    (N: 'fuchsia-500'; V: '#d946ef'),
    (N: 'fuchsia-600'; V: '#c026d3'),
    (N: 'fuchsia-700'; V: '#a21caf'),
    (N: 'fuchsia-800'; V: '#86198f'),
    (N: 'fuchsia-900'; V: '#701a75'),
    (N: 'fuchsia-950'; V: '#4a044e'),
    (N: 'pink-50'; V: '#fdf2f8'),
    (N: 'pink-100'; V: '#fce7f3'),
    (N: 'pink-200'; V: '#fbcfe8'),
    (N: 'pink-300'; V: '#f9a8d4'),
    (N: 'pink-400'; V: '#f472b6'),
    (N: 'pink-500'; V: '#ec4899'),
    (N: 'pink-600'; V: '#db2777'),
    (N: 'pink-700'; V: '#be185d'),
    (N: 'pink-800'; V: '#9d174d'),
    (N: 'pink-900'; V: '#831843'),
    (N: 'pink-950'; V: '#500724'),
    (N: 'rose-50'; V: '#fff1f2'),
    (N: 'rose-100'; V: '#ffe4e6'),
    (N: 'rose-200'; V: '#fecdd3'),
    (N: 'rose-300'; V: '#fda4af'),
    (N: 'rose-400'; V: '#fb7185'),
    (N: 'rose-500'; V: '#f43f5e'),
    (N: 'rose-600'; V: '#e11d48'),
    (N: 'rose-700'; V: '#be123c'),
    (N: 'rose-800'; V: '#9f1239'),
    (N: 'rose-900'; V: '#881337'),
    (N: 'rose-950'; V: '#4c0519')
  );

  // property groups order (shorthands before longhands, eg. "p-4 px-2" -> px-2 wins)
  O_DISPLAY = 10; O_POSITION = 20; O_INSET = 30; O_INSET_AXIS = 31; O_INSET_SIDE = 32; O_FLOAT = 40;
  O_OVERFLOW = 45; O_BOX = 50; O_FLEX_DIR = 60; O_FLEX_WRAP = 61; O_FLEX = 62; O_GROW = 63; O_SHRINK = 64;
  O_BASIS = 65; O_ORDER = 66; O_JUSTIFY = 70; O_ITEMS = 71; O_SELF = 72; O_GAP = 73; O_GAP_AXIS = 74;
  O_MARGIN = 100; O_MARGIN_AXIS = 101; O_MARGIN_SIDE = 102; O_PADDING = 110; O_PADDING_AXIS = 111;
  O_PADDING_SIDE = 112; O_SIZE = 120; O_WIDTH = 121; O_MIN_W = 122; O_MAX_W = 123; O_HEIGHT = 124;
  O_MIN_H = 125; O_MAX_H = 126; O_FONT_FAMILY = 200; O_FONT_SIZE = 201; O_FONT_WEIGHT = 202;
  O_FONT_STYLE = 203; O_TEXT_ALIGN = 204; O_TEXT_COLOR = 205; O_DECORATION = 206; O_WHITESPACE = 207;
  O_BG = 300; O_GRADIENT_FROM = 301; O_GRADIENT_VIA = 302; O_GRADIENT_TO = 303; O_BG_IMAGE = 304;
  O_BG_SIZE = 305; O_BG_POSITION = 306; O_BG_REPEAT = 307; O_BORDER_W = 310; O_BORDER_W_AXIS = 311; O_BORDER_W_SIDE = 312; O_BORDER_STYLE = 313;
  O_BORDER_COLOR = 314; O_ROUNDED = 320; O_ROUNDED_SIDE = 321; O_ROUNDED_CORNER = 322; O_SHADOW = 350;
  O_SHADOW_COLOR = 351; O_CURSOR = 400;

  TW_DEFAULT_BORDER_COLOR = '#e5e7eb';  // gray-200

  TW_SHADOW = 'var(--tw-shadow-color, rgb(0 0 0 / 0.1))';

  TW_STATIC: array[0..111] of record N, D: String; O: Integer; end = (
    (N: 'shadow-sm'; D: 'box-shadow:0 1px 2px 0 var(--tw-shadow-color, rgb(0 0 0 / 0.05))'; O: O_SHADOW),
    (N: 'shadow'; D: 'box-shadow:0 1px 3px 0 ' + TW_SHADOW + ', 0 1px 2px -1px ' + TW_SHADOW; O: O_SHADOW),
    (N: 'shadow-md'; D: 'box-shadow:0 4px 6px -1px ' + TW_SHADOW + ', 0 2px 4px -2px ' + TW_SHADOW; O: O_SHADOW),
    (N: 'shadow-lg'; D: 'box-shadow:0 10px 15px -3px ' + TW_SHADOW + ', 0 4px 6px -4px ' + TW_SHADOW; O: O_SHADOW),
    (N: 'shadow-xl'; D: 'box-shadow:0 20px 25px -5px ' + TW_SHADOW + ', 0 8px 10px -6px ' + TW_SHADOW; O: O_SHADOW),
    (N: 'shadow-2xl'; D: 'box-shadow:0 25px 50px -12px var(--tw-shadow-color, rgb(0 0 0 / 0.25))'; O: O_SHADOW),
    (N: 'shadow-inner'; D: 'box-shadow:inset 0 2px 4px 0 var(--tw-shadow-color, rgb(0 0 0 / 0.05))'; O: O_SHADOW),
    (N: 'shadow-none'; D: 'box-shadow:none'; O: O_SHADOW),
    (N: 'bg-none'; D: 'background-image:none'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-t'; D: 'background-image:linear-gradient(to top, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-tr'; D: 'background-image:linear-gradient(to top right, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-r'; D: 'background-image:linear-gradient(to right, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-br'; D: 'background-image:linear-gradient(to bottom right, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-b'; D: 'background-image:linear-gradient(to bottom, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-bl'; D: 'background-image:linear-gradient(to bottom left, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-l'; D: 'background-image:linear-gradient(to left, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-gradient-to-tl'; D: 'background-image:linear-gradient(to top left, var(--tw-gradient-stops))'; O: O_BG_IMAGE),
    (N: 'bg-auto'; D: 'background-size:auto'; O: O_BG_SIZE),
    (N: 'bg-cover'; D: 'background-size:cover'; O: O_BG_SIZE),
    (N: 'bg-contain'; D: 'background-size:contain'; O: O_BG_SIZE),
    (N: 'bg-center'; D: 'background-position:center'; O: O_BG_POSITION),
    (N: 'bg-top'; D: 'background-position:top'; O: O_BG_POSITION),
    (N: 'bg-bottom'; D: 'background-position:bottom'; O: O_BG_POSITION),
    (N: 'bg-left'; D: 'background-position:left'; O: O_BG_POSITION),
    (N: 'bg-right'; D: 'background-position:right'; O: O_BG_POSITION),
    (N: 'bg-left-top'; D: 'background-position:left top'; O: O_BG_POSITION),
    (N: 'bg-left-bottom'; D: 'background-position:left bottom'; O: O_BG_POSITION),
    (N: 'bg-right-top'; D: 'background-position:right top'; O: O_BG_POSITION),
    (N: 'bg-right-bottom'; D: 'background-position:right bottom'; O: O_BG_POSITION),
    (N: 'bg-repeat'; D: 'background-repeat:repeat'; O: O_BG_REPEAT),
    (N: 'bg-no-repeat'; D: 'background-repeat:no-repeat'; O: O_BG_REPEAT),
    (N: 'border-transparent'; D: 'border-color:transparent'; O: O_BORDER_COLOR),
    (N: 'from-transparent'; D: '--tw-gradient-from:transparent;--tw-gradient-to:transparent;--tw-gradient-stops:var(--tw-gradient-from), var(--tw-gradient-to)'; O: O_GRADIENT_FROM),
    (N: 'via-transparent'; D: '--tw-gradient-to:transparent;--tw-gradient-stops:var(--tw-gradient-from), transparent, var(--tw-gradient-to)'; O: O_GRADIENT_VIA),
    (N: 'to-transparent'; D: '--tw-gradient-to:transparent'; O: O_GRADIENT_TO),
    (N: 'bg-current'; D: 'background-color:currentcolor'; O: O_BG),
    (N: 'text-current'; D: 'color:currentcolor'; O: O_TEXT_COLOR),
    (N: 'block'; D: 'display:block'; O: O_DISPLAY),
    (N: 'inline-block'; D: 'display:inline-block'; O: O_DISPLAY),
    (N: 'inline'; D: 'display:inline'; O: O_DISPLAY),
    (N: 'flex'; D: 'display:flex'; O: O_DISPLAY),
    (N: 'inline-flex'; D: 'display:inline-flex'; O: O_DISPLAY),
    (N: 'hidden'; D: 'display:none'; O: O_DISPLAY),
    (N: 'static'; D: 'position:static'; O: O_POSITION),
    (N: 'relative'; D: 'position:relative'; O: O_POSITION),
    (N: 'absolute'; D: 'position:absolute'; O: O_POSITION),
    (N: 'fixed'; D: 'position:fixed'; O: O_POSITION),
    (N: 'sticky'; D: 'position:sticky'; O: O_POSITION),
    (N: 'float-left'; D: 'float:left'; O: O_FLOAT),
    (N: 'float-right'; D: 'float:right'; O: O_FLOAT),
    (N: 'float-none'; D: 'float:none'; O: O_FLOAT),
    (N: 'overflow-hidden'; D: 'overflow:hidden'; O: O_OVERFLOW),
    (N: 'overflow-visible'; D: 'overflow:visible'; O: O_OVERFLOW),
    (N: 'overflow-auto'; D: 'overflow:auto'; O: O_OVERFLOW),
    (N: 'overflow-scroll'; D: 'overflow:scroll'; O: O_OVERFLOW),
    (N: 'box-border'; D: 'box-sizing:border-box'; O: O_BOX),
    (N: 'box-content'; D: 'box-sizing:content-box'; O: O_BOX),
    (N: 'flex-row'; D: 'flex-direction:row'; O: O_FLEX_DIR),
    (N: 'flex-row-reverse'; D: 'flex-direction:row-reverse'; O: O_FLEX_DIR),
    (N: 'flex-col'; D: 'flex-direction:column'; O: O_FLEX_DIR),
    (N: 'flex-col-reverse'; D: 'flex-direction:column-reverse'; O: O_FLEX_DIR),
    (N: 'flex-wrap'; D: 'flex-wrap:wrap'; O: O_FLEX_WRAP),
    (N: 'flex-wrap-reverse'; D: 'flex-wrap:wrap-reverse'; O: O_FLEX_WRAP),
    (N: 'flex-nowrap'; D: 'flex-wrap:nowrap'; O: O_FLEX_WRAP),
    (N: 'flex-1'; D: 'flex:1 1 0%'; O: O_FLEX),
    (N: 'flex-auto'; D: 'flex:1 1 auto'; O: O_FLEX),
    (N: 'flex-initial'; D: 'flex:0 1 auto'; O: O_FLEX),
    (N: 'flex-none'; D: 'flex:none'; O: O_FLEX),
    (N: 'grow'; D: 'flex-grow:1'; O: O_GROW),
    (N: 'grow-0'; D: 'flex-grow:0'; O: O_GROW),
    (N: 'shrink'; D: 'flex-shrink:1'; O: O_SHRINK),
    (N: 'shrink-0'; D: 'flex-shrink:0'; O: O_SHRINK),
    (N: 'order-first'; D: 'order:-9999'; O: O_ORDER),
    (N: 'order-last'; D: 'order:9999'; O: O_ORDER),
    (N: 'order-none'; D: 'order:0'; O: O_ORDER),
    (N: 'justify-start'; D: 'justify-content:flex-start'; O: O_JUSTIFY),
    (N: 'justify-end'; D: 'justify-content:flex-end'; O: O_JUSTIFY),
    (N: 'justify-center'; D: 'justify-content:center'; O: O_JUSTIFY),
    (N: 'justify-between'; D: 'justify-content:space-between'; O: O_JUSTIFY),
    (N: 'justify-around'; D: 'justify-content:space-around'; O: O_JUSTIFY),
    (N: 'justify-evenly'; D: 'justify-content:space-evenly'; O: O_JUSTIFY),
    (N: 'items-start'; D: 'align-items:flex-start'; O: O_ITEMS),
    (N: 'items-end'; D: 'align-items:flex-end'; O: O_ITEMS),
    (N: 'items-center'; D: 'align-items:center'; O: O_ITEMS),
    (N: 'items-baseline'; D: 'align-items:baseline'; O: O_ITEMS),
    (N: 'items-stretch'; D: 'align-items:stretch'; O: O_ITEMS),
    (N: 'self-auto'; D: 'align-self:auto'; O: O_SELF),
    (N: 'self-start'; D: 'align-self:flex-start'; O: O_SELF),
    (N: 'self-end'; D: 'align-self:flex-end'; O: O_SELF),
    (N: 'self-center'; D: 'align-self:center'; O: O_SELF),
    (N: 'self-stretch'; D: 'align-self:stretch'; O: O_SELF),
    (N: 'self-baseline'; D: 'align-self:baseline'; O: O_SELF),
    (N: 'text-left'; D: 'text-align:left'; O: O_TEXT_ALIGN),
    (N: 'text-center'; D: 'text-align:center'; O: O_TEXT_ALIGN),
    (N: 'text-right'; D: 'text-align:right'; O: O_TEXT_ALIGN),
    (N: 'text-justify'; D: 'text-align:justify'; O: O_TEXT_ALIGN),
    (N: 'italic'; D: 'font-style:italic'; O: O_FONT_STYLE),
    (N: 'not-italic'; D: 'font-style:normal'; O: O_FONT_STYLE),
    (N: 'underline'; D: 'text-decoration:underline'; O: O_DECORATION),
    (N: 'line-through'; D: 'text-decoration:line-through'; O: O_DECORATION),
    (N: 'no-underline'; D: 'text-decoration:none'; O: O_DECORATION),
    (N: 'whitespace-nowrap'; D: 'white-space:nowrap'; O: O_WHITESPACE),
    (N: 'whitespace-normal'; D: 'white-space:normal'; O: O_WHITESPACE),
    (N: 'truncate'; D: 'overflow:hidden;white-space:nowrap'; O: O_WHITESPACE),
    (N: 'font-sans'; D: 'font-family:ui-sans-serif, system-ui, sans-serif'; O: O_FONT_FAMILY),
    (N: 'font-serif'; D: 'font-family:ui-serif, Georgia, Cambria, "Times New Roman", Times, serif'; O: O_FONT_FAMILY),
    (N: 'font-mono'; D: 'font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace'; O: O_FONT_FAMILY),
    (N: 'border-solid'; D: 'border-style:solid'; O: O_BORDER_STYLE),
    (N: 'border-dashed'; D: 'border-style:dashed'; O: O_BORDER_STYLE),
    (N: 'border-dotted'; D: 'border-style:dotted'; O: O_BORDER_STYLE),
    (N: 'border-none'; D: 'border-style:none'; O: O_BORDER_STYLE),
    (N: 'border-hidden'; D: 'border-style:hidden'; O: O_BORDER_STYLE)
  );

  TW_FONT_SIZES: array[0..12] of record N, V: String; end = (
    (N: 'xs'; V: '0.75rem'), (N: 'sm'; V: '0.875rem'), (N: 'base'; V: '1rem'), (N: 'lg'; V: '1.125rem'),
    (N: 'xl'; V: '1.25rem'), (N: '2xl'; V: '1.5rem'), (N: '3xl'; V: '1.875rem'), (N: '4xl'; V: '2.25rem'),
    (N: '5xl'; V: '3rem'), (N: '6xl'; V: '3.75rem'), (N: '7xl'; V: '4.5rem'), (N: '8xl'; V: '6rem'), (N: '9xl'; V: '8rem'));

  TW_FONT_WEIGHTS: array[0..8] of record N, V: String; end = (
    (N: 'thin'; V: '100'), (N: 'extralight'; V: '200'), (N: 'light'; V: '300'), (N: 'normal'; V: '400'),
    (N: 'medium'; V: '500'), (N: 'semibold'; V: '600'), (N: 'bold'; V: '700'), (N: 'extrabold'; V: '800'), (N: 'black'; V: '900'));

  TW_MAX_WIDTHS: array[0..12] of record N, V: String; end = (
    (N: 'xs'; V: '20rem'), (N: 'sm'; V: '24rem'), (N: 'md'; V: '28rem'), (N: 'lg'; V: '32rem'), (N: 'xl'; V: '36rem'),
    (N: '2xl'; V: '42rem'), (N: '3xl'; V: '48rem'), (N: '4xl'; V: '56rem'), (N: '5xl'; V: '64rem'), (N: '6xl'; V: '72rem'),
    (N: '7xl'; V: '80rem'), (N: 'none'; V: 'none'), (N: 'prose'; V: '65em'));

  TW_RADIUS: array[0..8] of record N, V: String; end = (
    (N: ''; V: '0.25rem'), (N: 'none'; V: '0px'), (N: 'sm'; V: '0.125rem'), (N: 'md'; V: '0.375rem'),
    (N: 'lg'; V: '0.5rem'), (N: 'xl'; V: '0.75rem'), (N: '2xl'; V: '1rem'), (N: '3xl'; V: '1.5rem'), (N: 'full'; V: '9999px'));

  TW_CURSORS: array[0..10] of String = ('auto', 'default', 'pointer', 'wait', 'text', 'move', 'help', 'not-allowed',
    'crosshair', 'grab', 'progress');

var
  TWColorList: TStringList;
  TWStaticList: TStringList;

function FloatToCSS(AValue: Double): String;
var
  fs: TFormatSettings;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  Result := FloatToStrF(AValue, ffGeneral, 8, 4, fs);
end;

function StrToCSSFloat(const S: String; out AValue: Double): Boolean;
var
  fs: TFormatSettings;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  Result := TryStrToFloat(S, AValue, fs);
end;

function IsArbitrary(const V: String; out AInner: String): Boolean;
begin
  Result := (Length(V) > 2) and (V[1] = '[') and (V[Length(V)] = ']');
  if Result then AInner := StringReplace(Copy(V, 2, Length(V) - 2), '_', ' ', [rfReplaceAll]);
end;

(*
  Spacing scale: 0, px, 0.5, 1, 1.5 ... (n * 0.25rem), fractions 1/2, full, auto, screen, arbitrary [..]
*)
function Spacing(const V: String; AllowFraction, AllowAuto, AllowFull: Boolean; out R: String): Boolean;
var
  D, A, B: Double;
  P: Integer;
begin
  Result := True;
  if IsArbitrary(V, R) then Exit;
  if V = 'px' then R := '1px' else
  if V = '0' then R := '0px' else
  if StrToCSSFloat(V, D) and (D >= 0) then R := FloatToCSS(D * 0.25) + 'rem' else
  if AllowAuto and (V = 'auto') then R := 'auto' else
  if AllowFull and (V = 'full') then R := '100%' else
  if AllowFull and (V = 'screen') then R := '100%' else
  begin
    P := Pos('/', V);
    Result := AllowFraction and (P > 1) and StrToCSSFloat(Copy(V, 1, P - 1), A) and StrToCSSFloat(Copy(V, P + 1, MaxInt), B) and (B > 0);
    if Result then R := FloatToCSS(A / B * 100) + '%';
  end;
end;

(*
  Color with alpha (0..1) in CSS format
*)
function ColorWithAlpha(const AColor: String; AAlpha: Double): String;
var
  C: TCSSColor;
begin
  C := CSSToColor(AColor);
  if C.ColorType <> cctNormal then Exit(AColor);
  C.Value := ColorToRGB(C.Value);
  Result := Format('rgba(%d,%d,%d,%s)', [Red(C.Value), Green(C.Value), Blue(C.Value), FloatToCSS(AAlpha * C.Alpha / 255)]);
end;

function TailwindColor(const AName: String; out AColor: String): Boolean;
var
  V, Opacity, Inner: String;
  X, Depth: Integer;
  A: Double;
begin
  Result := True;
  V := AName;
  Opacity := '';
  // opacity modifier: red-500/50, red-500/[0.35], [#ff0000]/50 (last "/" outside of [])
  Depth := 0;
  X := Length(V);
  while X > 0 do begin
    if V[X] = ']' then Inc(Depth)
    else if V[X] = '[' then Dec(Depth)
    else if (V[X] = '/') and (Depth = 0) then Break;
    Dec(X);
  end;
  if X > 0 then begin
    Opacity := Copy(V, X + 1, MaxInt);
    V := Copy(V, 1, X - 1);
  end;
  if Opacity <> '' then begin
    if IsArbitrary(Opacity, Inner) then begin
      if not StrToCSSFloat(Inner, A) then Exit(False);
    end else begin
      if not StrToCSSFloat(Opacity, A) then Exit(False);
      A := A / 100;
    end;
    Result := TailwindColor(V, AColor);
    if Result then AColor := ColorWithAlpha(AColor, EnsureRange(A, 0, 1));
    Exit;
  end;
  if IsArbitrary(V, AColor) then begin
    if CSSToColor(AColor).ColorType = cctUndefined then Result := False;
    Exit;
  end;
  if V = 'transparent' then AColor := 'transparent' else
  if V = 'current' then AColor := 'currentcolor' else
  if V = 'inherit' then AColor := 'inherit' else
  if V = 'black' then AColor := '#000000' else
  if V = 'white' then AColor := '#ffffff' else
  if TWColorList.Find(V, X) then AColor := TW_COLORS[PtrInt(TWColorList.Objects[X])].V else
    Result := False;
end;

function FindIn(const AName: String; const ANames: array of String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ANames) do
    if ANames[I] = AName then Exit(True);
  Result := False;
end;

(*
  AName starts with APrefix, AValue is rest of the name
*)
function HasPrefix(const AName, APrefix: String; out AValue: String): Boolean;
begin
  Result := (Length(AName) > Length(APrefix)) and (Copy(AName, 1, Length(APrefix)) = APrefix);
  if Result then AValue := Copy(AName, Length(APrefix) + 1, MaxInt) else AValue := '';
end;

function TailwindResolve(const AClassName: String; out ADeclarations: String; out AOrder: Integer): Boolean;
var
  Name, V, R, C, W: String;
  Neg: Boolean;
  I: Integer;
  D: Double;

  function Done(const ADecl: String; AOrd: Integer): Boolean;
  begin
    ADeclarations := ADecl;
    AOrder := AOrd;
    Result := True;
  end;
  function Negate(const AValue: String): String;
  begin
    if Neg and (AValue <> '0px') and (AValue <> 'auto') then Result := '-' + AValue else Result := AValue;
  end;
  // spacing utility with optional axis/sides: eg. p-4, px-4, pt-4
  function SidesUtility(const APrefix, AProp: String; AOrd: Integer; AllowAuto, AllowNeg: Boolean): Boolean;
  const
    Sides: array[0..6] of record S, P1, P2: String; O: Integer; end = (
      (S: '-'; P1: ''; P2: ''; O: 0), (S: 'x-'; P1: '-left'; P2: '-right'; O: 1), (S: 'y-'; P1: '-top'; P2: '-bottom'; O: 1),
      (S: 't-'; P1: '-top'; P2: ''; O: 2), (S: 'r-'; P1: '-right'; P2: ''; O: 2), (S: 'b-'; P1: '-bottom'; P2: ''; O: 2),
      (S: 'l-'; P1: '-left'; P2: ''; O: 2));
  var
    J: Integer;
    Val, Res: String;
  begin
    Result := False;
    if Neg and not AllowNeg then Exit;
    for J := 0 to High(Sides) do
      if HasPrefix(Name, APrefix + Sides[J].S, Val) and Spacing(Val, False, AllowAuto, False, Res) then begin
        Res := Negate(Res);
        if Sides[J].P1 = '' then Exit(Done(AProp + ':' + Res, AOrd))
        else if Sides[J].P2 = '' then Exit(Done(AProp + Sides[J].P1 + ':' + Res, AOrd + Sides[J].O))
        else Exit(Done(AProp + Sides[J].P1 + ':' + Res + ';' + AProp + Sides[J].P2 + ':' + Res, AOrd + Sides[J].O));
      end;
  end;
  function BorderWidthValue(const AValue: String; out ARes: String): Boolean;
  begin
    Result := True;
    if AValue = '' then ARes := '1px'
    else if IsArbitrary(AValue, ARes) then
    else if (AValue = '0') or (AValue = '2') or (AValue = '4') or (AValue = '8') then ARes := AValue + 'px'
    else Result := False;
  end;
  function RadiusValue(const AValue: String; out ARes: String): Boolean;
  var
    J: Integer;
  begin
    if IsArbitrary(AValue, ARes) then Exit(True);
    for J := 0 to High(TW_RADIUS) do
      if TW_RADIUS[J].N = AValue then begin
        ARes := TW_RADIUS[J].V;
        Exit(True);
      end;
    Result := False;
  end;
begin
  Result := False;
  ADeclarations := '';
  AOrder := 0;
  Name := AClassName;
  if Name = '' then Exit;

  // static utilities
  if TWStaticList.Find(Name, I) then
    Exit(Done(TW_STATIC[PtrInt(TWStaticList.Objects[I])].D, TW_STATIC[PtrInt(TWStaticList.Objects[I])].O));

  Neg := Name[1] = '-';
  if Neg then Delete(Name, 1, 1);

  // spacing
  if SidesUtility('p', 'padding', O_PADDING, False, False) then Exit(True);
  if SidesUtility('m', 'margin', O_MARGIN, True, True) then Exit(True);

  // inset
  if HasPrefix(Name, 'inset-x-', V) and Spacing(V, True, True, True, R) then
    Exit(Done('left:' + Negate(R) + ';right:' + Negate(R), O_INSET_AXIS));
  if HasPrefix(Name, 'inset-y-', V) and Spacing(V, True, True, True, R) then
    Exit(Done('top:' + Negate(R) + ';bottom:' + Negate(R), O_INSET_AXIS));
  if HasPrefix(Name, 'inset-', V) and Spacing(V, True, True, True, R) then
    Exit(Done('inset:' + Negate(R), O_INSET));
  for V in TStringArray.Create('top', 'right', 'bottom', 'left') do
    if HasPrefix(Name, V + '-', C) and Spacing(C, True, True, True, R) then
      Exit(Done(V + ':' + Negate(R), O_INSET_SIDE));

  // order
  if HasPrefix(Name, 'order-', V) and TryStrToInt(V, I) then
    Exit(Done('order:' + Negate(V), O_ORDER));
  if Neg then Exit;     // other utilities can't be negative

  // flexbox
  if HasPrefix(Name, 'basis-', V) and Spacing(V, True, True, True, R) then Exit(Done('flex-basis:' + R, O_BASIS));
  if HasPrefix(Name, 'grow-', V) and IsArbitrary(V, R) then Exit(Done('flex-grow:' + R, O_GROW));
  if HasPrefix(Name, 'shrink-', V) and IsArbitrary(V, R) then Exit(Done('flex-shrink:' + R, O_SHRINK));
  if HasPrefix(Name, 'gap-x-', V) and Spacing(V, False, False, False, R) then Exit(Done('column-gap:' + R, O_GAP_AXIS));
  if HasPrefix(Name, 'gap-y-', V) and Spacing(V, False, False, False, R) then Exit(Done('row-gap:' + R, O_GAP_AXIS));
  if HasPrefix(Name, 'gap-', V) and Spacing(V, False, False, False, R) then Exit(Done('gap:' + R, O_GAP));

  // sizing
  if HasPrefix(Name, 'size-', V) and Spacing(V, True, True, True, R) then Exit(Done('width:' + R + ';height:' + R, O_SIZE));
  if HasPrefix(Name, 'w-', V) and Spacing(V, True, True, True, R) then Exit(Done('width:' + R, O_WIDTH));
  if HasPrefix(Name, 'h-', V) and Spacing(V, True, True, True, R) then Exit(Done('height:' + R, O_HEIGHT));
  if HasPrefix(Name, 'min-w-', V) and Spacing(V, True, False, True, R) then Exit(Done('min-width:' + R, O_MIN_W));
  if HasPrefix(Name, 'min-h-', V) and Spacing(V, True, False, True, R) then Exit(Done('min-height:' + R, O_MIN_H));
  if HasPrefix(Name, 'max-h-', V) and Spacing(V, True, False, True, R) then Exit(Done('max-height:' + R, O_MAX_H));
  if HasPrefix(Name, 'max-h-', V) and (V = 'none') then Exit(Done('max-height:none', O_MAX_H));
  if HasPrefix(Name, 'max-w-', V) then begin
    for I := 0 to High(TW_MAX_WIDTHS) do
      if TW_MAX_WIDTHS[I].N = V then Exit(Done('max-width:' + TW_MAX_WIDTHS[I].V, O_MAX_W));
    if Spacing(V, True, False, True, R) then Exit(Done('max-width:' + R, O_MAX_W));
  end;

  // typography
  if HasPrefix(Name, 'text-', V) then begin
    for I := 0 to High(TW_FONT_SIZES) do
      if TW_FONT_SIZES[I].N = V then Exit(Done('font-size:' + TW_FONT_SIZES[I].V, O_FONT_SIZE));
    if IsArbitrary(V, R) and (R <> '') and (R[1] in ['0'..'9', '.']) then Exit(Done('font-size:' + R, O_FONT_SIZE));
    if TailwindColor(V, C) then Exit(Done('color:' + C, O_TEXT_COLOR));
  end;
  if HasPrefix(Name, 'font-', V) then begin
    for I := 0 to High(TW_FONT_WEIGHTS) do
      if TW_FONT_WEIGHTS[I].N = V then Exit(Done('font-weight:' + TW_FONT_WEIGHTS[I].V, O_FONT_WEIGHT));
    if IsArbitrary(V, R) then begin
      if StrToCSSFloat(R, D) then Exit(Done('font-weight:' + R, O_FONT_WEIGHT))
        else Exit(Done('font-family:' + R, O_FONT_FAMILY));
    end;
  end;

  // backgrounds
  if HasPrefix(Name, 'bg-', V) then begin
    if IsArbitrary(V, R) then begin
      if SameText(Copy(R, 1, 4), 'url(') or SameText(Copy(R, 1, 16), 'linear-gradient(') then
        Exit(Done('background-image:' + R, O_BG_IMAGE));
      if HasPrefix(R, 'length:', C) then Exit(Done('background-size:' + C, O_BG_SIZE));        // bg-[length:20px_10px]
      if HasPrefix(R, 'position:', C) then Exit(Done('background-position:' + C, O_BG_POSITION));
    end;
    if TailwindColor(V, C) then Exit(Done('background-color:' + C, O_BG));
  end;
  // gradient color stops (custom properties like Tailwind)
  if HasPrefix(Name, 'from-', V) and TailwindColor(V, C) then
    Exit(Done('--tw-gradient-from:' + C + ';--tw-gradient-to:' + ColorWithAlpha(C, 0) +
      ';--tw-gradient-stops:var(--tw-gradient-from), var(--tw-gradient-to)', O_GRADIENT_FROM));
  if HasPrefix(Name, 'via-', V) and TailwindColor(V, C) then
    Exit(Done('--tw-gradient-to:' + ColorWithAlpha(C, 0) +
      ';--tw-gradient-stops:var(--tw-gradient-from), ' + C + ', var(--tw-gradient-to)', O_GRADIENT_VIA));
  if HasPrefix(Name, 'to-', V) and TailwindColor(V, C) then
    Exit(Done('--tw-gradient-to:' + C, O_GRADIENT_TO));

  // borders (Tailwind preflight sets border-style: solid and default border color for all elements)
  if Name = 'border' then Exit(Done('border-width:1px;border-style:solid;border-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W));
  if HasPrefix(Name, 'border-', V) then begin
    if BorderWidthValue(V, R) then
      Exit(Done('border-width:' + R + ';border-style:solid;border-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W));
    for C in TStringArray.Create('x', 'y', 't', 'r', 'b', 'l') do
      if (V = C) or HasPrefix(V, C + '-', W) and BorderWidthValue(W, R) then begin
        if V = C then R := '1px';
        case C[1] of
          'x': Exit(Done('border-left-width:' + R + ';border-right-width:' + R + ';border-left-style:solid;border-right-style:solid;' +
                 'border-left-color:' + TW_DEFAULT_BORDER_COLOR + ';border-right-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_AXIS));
          'y': Exit(Done('border-top-width:' + R + ';border-bottom-width:' + R + ';border-top-style:solid;border-bottom-style:solid;' +
                 'border-top-color:' + TW_DEFAULT_BORDER_COLOR + ';border-bottom-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_AXIS));
          't': Exit(Done('border-top-width:' + R + ';border-top-style:solid;border-top-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_SIDE));
          'r': Exit(Done('border-right-width:' + R + ';border-right-style:solid;border-right-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_SIDE));
          'b': Exit(Done('border-bottom-width:' + R + ';border-bottom-style:solid;border-bottom-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_SIDE));
          'l': Exit(Done('border-left-width:' + R + ';border-left-style:solid;border-left-color:' + TW_DEFAULT_BORDER_COLOR, O_BORDER_W_SIDE));
        end;
      end;
    if TailwindColor(V, C) then Exit(Done('border-color:' + C, O_BORDER_COLOR));
  end;

  // border radius
  if (Name = 'rounded') or HasPrefix(Name, 'rounded-', V) then begin
    if RadiusValue(V, R) then Exit(Done('border-radius:' + R, O_ROUNDED));
    for C in TStringArray.Create('tl', 'tr', 'br', 'bl', 't', 'r', 'b', 'l') do
      if (V = C) or HasPrefix(V, C + '-', W) then begin
        if V = C then W := '';
        if not RadiusValue(W, R) then Exit;
        case C of
          't': Exit(Done('border-top-left-radius:' + R + ';border-top-right-radius:' + R, O_ROUNDED_SIDE));
          'r': Exit(Done('border-top-right-radius:' + R + ';border-bottom-right-radius:' + R, O_ROUNDED_SIDE));
          'b': Exit(Done('border-bottom-right-radius:' + R + ';border-bottom-left-radius:' + R, O_ROUNDED_SIDE));
          'l': Exit(Done('border-top-left-radius:' + R + ';border-bottom-left-radius:' + R, O_ROUNDED_SIDE));
          'tl': Exit(Done('border-top-left-radius:' + R, O_ROUNDED_CORNER));
          'tr': Exit(Done('border-top-right-radius:' + R, O_ROUNDED_CORNER));
          'br': Exit(Done('border-bottom-right-radius:' + R, O_ROUNDED_CORNER));
          'bl': Exit(Done('border-bottom-left-radius:' + R, O_ROUNDED_CORNER));
        end;
      end;
  end;

  // colored shadow
  if HasPrefix(Name, 'shadow-', V) and TailwindColor(V, C) then Exit(Done('--tw-shadow-color:' + C, O_SHADOW_COLOR));
  // cursor
  if HasPrefix(Name, 'cursor-', V) and FindIn(V, TW_CURSORS) then Exit(Done('cursor:' + V, O_CURSOR));
end;

procedure CSSTailwindEnable(ABorderBox: Boolean);
begin
  CSSUtilityResolver := @TailwindResolve;
  if ABorderBox then CSSDefaultBoxSizing := cbxBorderBox;   // Tailwind preflight: * { box-sizing: border-box }
  CSSClearUtilityCache;
end;

procedure CSSTailwindDisable;
begin
  if CSSUtilityResolver = @TailwindResolve then CSSUtilityResolver := nil;
  CSSDefaultBoxSizing := cbxContentBox;
  CSSClearUtilityCache;
end;

procedure InitTailwind;
var
  I: Integer;
begin
  TWColorList := TStringList.Create;
  for I := 0 to High(TW_COLORS) do
    TWColorList.AddObject(TW_COLORS[I].N, TObject(PtrInt(I)));
  TWColorList.Sorted := True;
  TWStaticList := TStringList.Create;
  for I := 0 to High(TW_STATIC) do
    TWStaticList.AddObject(TW_STATIC[I].N, TObject(PtrInt(I)));
  TWStaticList.Sorted := True;
  TWStaticList.CaseSensitive := True;
  TWColorList.CaseSensitive := True;
end;

initialization
  InitTailwind;

finalization
  TWColorList.Free;
  TWStaticList.Free;

end.
