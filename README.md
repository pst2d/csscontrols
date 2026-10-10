# csscontrols

CSS layout and drawing for Pascal (Free Pascal / Lazarus). Build Lazarus user interfaces from a tree of
nodes styled with CSS, or with [Tailwind CSS](https://tailwindcss.com/)-like utility classes, so you get the
layout flexibility of a web app in a native application.

```pascal
uses cssbase, CSSCtrls, csstailwind;

CSSTailwindEnable;  // once, at application start

Card := HTMLNode('max-w-sm mx-auto flex items-center gap-4 p-6 bg-white rounded-xl border border-slate-200')
  .AppendTo(CSSShape1.Body);
HTMLNode('size-12 shrink-0 rounded-full bg-sky-500').AppendTo(Card);
HTMLNode('text-xl font-medium text-black', 'ChitChat').AppendTo(Card);
HTMLNode('px-4 py-2 rounded-lg bg-violet-600 hover:bg-violet-700 text-white cursor-pointer', 'Follow')
  .SetOnClick(@FollowClick)
  .AppendTo(Card);
CSSShape1.Changed;
```

> Work in progress: the API can still change.

## Features

- `TCSSShape` component (palette page *CSS*) that paints a node tree and handles hover, active state,
  clicks and cursors
- Box model: margin, padding, border, `box-sizing`, `min-*`/`max-*` sizes, `px`, `pt`, `em`, `rem`, `%`
- Layout: block, inline, `float`, `position` (relative, absolute), `overflow: hidden`, `margin: auto`
- Flexbox: `flex-direction`, `flex-wrap`, `gap`, `flex-grow`/`flex-shrink`/`flex-basis`, `justify-content`,
  `align-items`, `align-self`, auto margins, `order`
- Text: font size, family, weight, style, decoration, alignment, wrapping
- Colors: all CSS named colors, `#rgb`, `#rrggbb`, `rgb()`, `rgba()`, `transparent`, `currentcolor`
- Rounded borders, per-side border width, color and style
- Stylesheets with selectors: element, `*`, `.class`, `#id`, `:hover`, `:active`, `:first-child`,
  `:last-child`, descendant and child (`>`) combinators, cascade by specificity and order
- Utility classes (`csstailwind.pas`), see below
- LCL controls can be placed inside nodes (`SetAlignControl`), so a `TEdit` follows the CSS layout
- High DPI: CSS pixels are scaled by screen DPI on Windows and Linux (`TCSSShape.ScaleByDPI`)

## Utility classes

`CSSTailwindEnable` registers a resolver that turns class names into CSS while styles are applied, so you
don't need a generated stylesheet. It covers a subset of Tailwind CSS v3:

| Group | Classes |
|---|---|
| Layout | `block` `inline-block` `inline` `flex` `inline-flex` `hidden` `relative` `absolute` `inset-*` `top-*` `left-*` ... `float-*` `overflow-*` `box-border` |
| Flexbox | `flex-row` `flex-col` `flex-wrap` `flex-1` `flex-none` `grow` `shrink-0` `basis-*` `order-*` `justify-*` `items-*` `self-*` `gap-*` `gap-x-*` `gap-y-*` |
| Spacing | `p-*` `px-*` `py-*` `pt-*` ... `m-*` `mx-auto` `-mt-2` ... |
| Sizing | `w-*` `h-*` `size-*` `min-w-*` `max-w-md` ... (spacing scale, fractions `w-1/2`, `full`, `screen`) |
| Typography | `text-xs` ... `text-9xl`, `text-center`, `text-{color}`, `font-bold` ..., `font-mono`, `italic`, `underline`, `line-through`, `truncate` |
| Backgrounds | `bg-{color}` |
| Borders | `border` `border-2` `border-t` ... `border-{color}` `border-dashed` `rounded` `rounded-lg` `rounded-full` `rounded-t-xl` ... |
| Other | `cursor-*` |

- Full Tailwind color palette (`slate` ... `rose`, shades `50` to `950`)
- Arbitrary values: `w-[200px]`, `bg-[#ff8800]`, `text-[13px]`
- Variants: `hover:`, `active:`, `first:`, `last:`, `odd:`, `even:`, `group-hover:`
- Responsive variants `sm:` `md:` `lg:` `xl:` `2xl:` use the width of the `TCSSShape` control, so they act
  like container queries
- Utility classes can be mixed with a regular stylesheet. Utilities are applied after stylesheet rules.

Not supported yet: opacity modifiers (`bg-black/50` ignores the opacity), shadows, transitions,
transforms, grid, `space-x-*`, dark mode.

## Stylesheets

```pascal
Sheet := TCSSStyleSheet.Create(Self);
Sheet.Style := '.menu { display: flex; gap: 4px } .menu > .item:hover { background-color: #f3f4f6 }';
CSSShape1.Body.StyleSheet := Sheet;
HTMLNode('menu').AppendTo(CSSShape1.Body);
```

## Install

Open `csspckg_lazarus.lpk` in Lazarus, compile it and install it (*Use > Install*).

## Demo and tests

- `demo/csscontrols_demo.lpi`: demo application with several scenes (cards, buttons, flexbox, responsive
  layout, typography, dashboard, stylesheet, LCL controls)
- `demo/renderdemo.lpi`: renders the demo scenes to PNG files, which is handy for checking changes visually
- `tests/csstests.lpi`: fpcunit tests (console runner)

```sh
lazbuild tests/csstests.lpi && tests/csstests
lazbuild demo/renderdemo.lpi && demo/renderdemo demo/out 720
```

## Limitations

- Delphi/FMX is not supported yet. Some code paths exist, but they are incomplete.
- Borders are always painted solid, and edges are not antialiased.
- Text inside a node is laid out as one block (no inline formatting across nodes).

## License

Apache License 2.0, see [LICENSE](LICENSE).

The color palette in `csstailwind.pas` comes from Tailwind CSS, Copyright (c) Tailwind Labs, Inc.,
MIT License. This project is not affiliated with Tailwind Labs.
