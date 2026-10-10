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
- Rounded borders, per-side border width, color and style (`solid`, `dashed`, `dotted`), painted with
  antialiasing (same result on every platform, corners are cached, so repainting is fast)
- Backgrounds: colors with alpha, `linear-gradient(...)`, images (`url(...)`, `background-size`,
  `background-position`, `background-repeat`)
- Shadows: `box-shadow` with offset, blur, spread, color, more shadows (inset shadows are not supported yet)
- Transforms: `transform` (`translate`, `scale`, `rotate`, `skew`, `matrix`), `transform-origin` and the
  `translate`, `rotate`, `scale` properties. As in CSS, transforms don't change the layout. Hover, active
  and click use the transformed shape. Translated nodes are painted directly. Scaled and rotated nodes
  are painted into a cached bitmap. LCL controls inside nodes are moved and scaled, but not rotated.
- Basic HTML markup (`csshtml.pas`), see below
- Custom properties (`--name: value`) and `var()` in background images and shadows
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
| Backgrounds | `bg-{color}` `bg-gradient-to-r` `from-*` `via-*` `to-*` `bg-[url(file.png)]` `bg-cover` `bg-contain` `bg-center` `bg-no-repeat` ... |
| Borders | `border` `border-2` `border-t` ... `border-{color}` `border-dashed` `rounded` `rounded-lg` `rounded-full` `rounded-t-xl` ... |
| Shadows | `shadow-sm` `shadow` `shadow-md` `shadow-lg` `shadow-xl` `shadow-2xl` `shadow-none` `shadow-{color}` |
| Transforms | `translate-x-*` `-translate-y-1/2` `rotate-45` `scale-105` `scale-x-*` `skew-x-*` `origin-*` |
| Images | `object-cover` `object-contain` `object-fill` `object-center` ... |
| Other | `cursor-*` |

- Full Tailwind color palette (`slate` ... `rose`, shades `50` to `950`)
- Arbitrary values: `w-[200px]`, `bg-[#ff8800]`, `text-[13px]`, `bg-[length:60px_40px]`
- Opacity modifiers: `bg-black/50`, `text-white/70`, `border-slate-900/10`
- Variants: `hover:`, `active:`, `first:`, `last:`, `odd:`, `even:`, `group-hover:`
- Responsive variants `sm:` `md:` `lg:` `xl:` `2xl:` use the width of the `TCSSShape` control, so they act
  like container queries
- Utility classes can be mixed with a regular stylesheet. Utilities are applied after stylesheet rules.

Not supported yet: `shadow-inner`, transitions, grid, `space-x-*`, dark mode.

## HTML markup

`csshtml.pas` lets you describe UI with HTML markup, for example copied from Tailwind CSS examples.
It covers visual markup only: no scripts, no forms and no browser behavior. Interaction stays in Pascal.

```pascal
uses cssbase, csshtml;

CSSShape1.Body.AppendHTML(
  '<div class="flex flex-col items-center p-7 rounded-2xl">' +
  '  <img class="size-48 shadow-xl rounded-md" src="cover.png">' +
  '  <span id="title" class="text-2xl font-medium">Class Warfare</span>' +
  '  <span class="font-medium text-sky-500">The Anti-Patterns</span>' +
  '</div>');
CSSShape1.Body.GetElementById('title').OnClick := @TitleClick;
```

- Elements with `class`, `style` and `id`. Other attributes are available as `Node.Attributes['name']`.
- Text, entities (`&middot;`, `&#183;`, ...), `<br>`, `<b>`, `<i>`, `<code>` and other basic element styles.
- `<img src>` with intrinsic size and aspect ratio. It is painted as a background image, so
  `rounded-*`, `shadow-*` and `object-fit` work.
- `<style>` is appended to the stylesheet of the root node.

## Background images

`url(...)` takes a file name, either absolute or relative to the application folder. It can also take a
name registered from code, for example an image from resources:

```pascal
CSSRegisterImage('logo', MyPicture.Graphic);
Node.SetClass('h-32 bg-[url(logo)] bg-contain bg-center bg-no-repeat');
```

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
  layout, typography, dashboard, stylesheet, borders, backgrounds, LCL controls)
- `demo/renderdemo.lpi`: renders the demo scenes to PNG files, which is handy for checking changes visually
  (`renderdemo out 720 Borders 4` renders one scene zoomed 4x, `renderdemo bench` measures paint time)
- `tests/csstests.lpi`: fpcunit tests (console runner)

```sh
lazbuild tests/csstests.lpi && tests/csstests
lazbuild demo/renderdemo.lpi && demo/renderdemo demo/out 720
```

## Limitations

- Delphi/FMX is not supported yet. Some code paths exist, but they are incomplete.
- Dashed borders have solid rounded corners. Dotted borders follow rounded corners only if all sides
  have the same width and color.
- Scaled and rotated content is painted through a bitmap, so text in it is a bit softer than normal text.
- Colors with alpha are blended with the nearest background color for text and borders. Backgrounds
  use a real alpha channel.
- A shadow is also painted under the node itself, so it can be seen through a transparent background.

## Performance

Painting is done with the LCL canvas only, no extra libraries are used:

- Straight parts of backgrounds and borders are drawn with `FillRect`.
- Background images and horizontal or vertical gradients are drawn with `StretchDraw`.
- Rounded corners, border joins and diagonal gradients are rasterized with antialiasing into small bitmaps,
  which are cached. Equal corners of different nodes share one bitmap.
- Shadows are cut into 9 cached parts (corners, edges, center), so their cost doesn't depend on node size.
- Bitmaps are rendered in device resolution (2x on macOS Retina).

`demo/renderdemo resize` measures painting while a window is being resized.
- Text inside a node is laid out as one block (no inline formatting across nodes).

## License

Apache License 2.0, see [LICENSE](LICENSE).

The color palette in `csstailwind.pas` comes from Tailwind CSS, Copyright (c) Tailwind Labs, Inc.,
MIT License. This project is not affiliated with Tailwind Labs.
