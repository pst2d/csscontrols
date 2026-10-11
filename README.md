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

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/architecture-dark.svg">
  <img src="docs/images/architecture.svg" alt="HTML, CSS and Pascal code go to the csscontrols engine (parse and cascade, layout, painting, interaction), which draws on the LCL canvas and places native LCL controls, so the result is a native desktop application">
</picture>

## Screenshots

Kanban board (`demo/kanban/kanban.lpi`), a small Trello-like application: drag and drop of cards, task
detail with native `TEdit`/`TMemo`, search, filters, dark mode and Lucide icons:

<p>
<img src="docs/images/kanban-drag.png" width="100%" alt="Kanban board while a card is dragged">
<img src="docs/images/kanban-detail.png" width="49%" alt="Task detail">
<img src="docs/images/kanban-dark.png" width="49%" alt="Kanban board in dark mode">
</p>

Scenes of the demo application (`demo/csscontrols_demo.lpi`), painted by the engine:

<p>
<img src="docs/images/chat-app.png" width="49%" alt="Chat app">
<img src="docs/images/shop.png" width="49%" alt="Shop">
<img src="docs/images/settings.png" width="49%" alt="Settings">
<img src="docs/images/calendar.png" width="49%" alt="Calendar">
<img src="docs/images/dashboard.png" width="49%" alt="Dashboard">
<img src="docs/images/grid.png" width="49%" alt="Grid">
<img src="docs/images/forms.png" width="32%" alt="Inputs">
<img src="docs/images/transforms.png" width="32%" alt="Transforms">
<img src="docs/images/borders.png" width="32%" alt="Borders">
</p>

## Features

- `TCSSShape` component (palette page *CSS*) that paints a node tree and handles hover, active state,
  clicks and cursors
- Box model: margin, padding, border, `box-sizing`, `min-*`/`max-*` sizes, `px`, `pt`, `em`, `rem`, `%`
- Layout: block, inline, `float`, `position` (relative, absolute), `z-index`, `margin: auto`
- Scrolling: `overflow: auto | scroll | hidden` (also `overflow-x`, `overflow-y`) with thin overlay
  scrollbars (`scrollbar-width: none` hides them), mouse wheel and dragging of the scrollbar thumb. Steps of
  the mouse wheel are scrolled smoothly, touchpads scroll by exact pixels. The vertical wheel scrolls
  content which scrolls only horizontally (for example tabs). The wheel over LCL controls in nodes
  (`TEdit` ...) scrolls the content too. Scrolling only repaints the control, the
  layout is not recalculated. Content that overflows at the top (for example a chat list with
  `justify-content: flex-end`) starts at the bottom. Children touching the rounded corners of a parent
  with `overflow: hidden` get its inner radius, so input groups and cards with images look right.
- Flexbox: `flex-direction`, `flex-wrap`, `gap`, `flex-grow`/`flex-shrink`/`flex-basis`, `justify-content`,
  `align-items`, `align-self`, auto margins, `order`
- Grid (KISS subset): `grid-template-columns`/`grid-template-rows` with `px`, `%`, `rem`, `fr`, `auto`,
  `minmax()` and `repeat()`, automatic placement, `grid-column: span N` (`1 / -1` for whole row),
  `grid-row: span N`, `gap`, `align-items`/`align-self` in cells. Line numbers, template areas,
  `auto-fill` and dense placement are not supported.
- Opacity, transitions and animations (minimal), see below
- Dark mode: `dark:` variant of utility classes, switched by `CSSSetDarkMode(True)`
- `position: sticky` (vertical, for example headers of sections in a scrolled list), `line-clamp`
  (text cut to N lines with an ellipsis), `aspect-ratio`
- Text: font size, family, weight, style, decoration, alignment, wrapping
- Colors: all CSS named colors, `#rgb`, `#rrggbb`, `rgb()`, `rgba()`, `transparent`, `currentcolor`
- Rounded borders, per-side border width, color and style (`solid`, `dashed`, `dotted`, also mixed),
  painted with antialiasing (same result on every platform, corners are cached, so repainting is fast).
  Dashes and dots follow rounded corners.
- Backgrounds: colors with alpha, `linear-gradient(...)`, images (`url(...)`, `background-size`,
  `background-position`, `background-repeat`)
- Shadows: `box-shadow` with offset, blur, spread, color, more shadows, `inset` shadows
- Transforms: `transform` (`translate`, `scale`, `rotate`, `skew`, `matrix`), `transform-origin` and the
  `translate`, `rotate`, `scale` properties. As in CSS, transforms don't change the layout. Hover, active
  and click use the transformed shape. Translated nodes are painted directly. Scaled and rotated nodes
  are laid out again in the target resolution and painted into a cached bitmap, so text stays sharp.
  LCL controls inside nodes are moved and scaled, but not rotated.
- Tooltips and other hover popups with CSS only: an absolute child shown by `group-hover:`, for example
  `opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none`
- `pointer-events: none` (the node and its children are ignored by the mouse)
- Basic HTML markup (`csshtml.pas`), see below
- Icons: inline `<svg>` copied from [lucide.dev](https://lucide.dev) (or other stroke icon sets) is painted
  by the engine with antialiasing, in the text color, see below
- Own data in nodes: `Node.Tag` (number), `Node.TagStr` and `Node.Attributes['data-...']` (texts),
  `Node.Data` (object, freed with the node when `Node.OwnsData` is set)
- Ready made components (`csscomponents.pas`): `TCSSButton`, `TCSSToggle`, `TCSSBadge`, `TCSSAvatar`,
  `TCSSTabs`, and `HTML`, `CSS` and `BodyClass` properties of `TCSSShape` for the form designer, see below
- Custom properties (`--name: value`) and `var()` in background images and shadows
- Stylesheets with selectors: element, `*`, `.class`, `#id`, `:hover`, `:active`, `:first-child`,
  `:last-child`, descendant and child (`>`) combinators, cascade by specificity and order
- Utility classes (`csstailwind.pas`), see below
- LCL controls can be placed inside nodes (`SetAlignControl`), so a `TEdit` follows the CSS layout. A
  borderless `TEdit` inside a styled node gives rounded inputs with shadows, inner buttons and so on.
  `TCSSShape` tracks the focused control, so `focus:` and `focus-within:` styles work
  (for example `focus-within:ring-4 focus-within:ring-indigo-100`). Controls in scrolled content are
  moved, and hidden while they are not fully visible. A click on a node without `OnClick` focuses the
  control inside it, when the node or its nearest parent contains exactly one focusable control (like a
  click on `<label>` in HTML), so a click on the padding of an input wrapper or on the field label works.
- Inspect mode for debugging (`TCSSShape.Inspect := True`): like the inspector of a browser, it shows the
  margin, border, padding and content box of the node under the mouse, guide lines and a label with the
  element, classes and size. `OnInspect` reports the node, for example to show its box model in a status bar.
- High DPI: CSS pixels are scaled by screen DPI on Windows and Linux (`TCSSShape.ScaleByDPI`)

## Utility classes

`CSSTailwindEnable` registers a resolver that turns class names into CSS while styles are applied, so you
don't need a generated stylesheet. It covers a subset of Tailwind CSS v3:

| Group | Classes |
|---|---|
| Layout | `block` `inline-block` `inline` `flex` `inline-flex` `hidden` `relative` `absolute` `sticky` `inset-*` `top-*` `left-*` ... `float-*` `overflow-*` `box-border` |
| Flexbox | `flex-row` `flex-col` `flex-wrap` `flex-1` `flex-none` `grow` `shrink-0` `basis-*` `order-*` `justify-*` `items-*` `self-*` `gap-*` `gap-x-*` `gap-y-*` |
| Grid | `grid` `grid-cols-3` `grid-cols-[200px_1fr]` `grid-rows-*` `col-span-2` `col-span-full` `row-span-2` |
| Spacing | `p-*` `px-*` `py-*` `pt-*` ... `m-*` `mx-auto` `-mt-2` ... `space-x-*` `space-y-*` |
| Sizing | `w-*` `h-*` `size-*` `min-w-*` `max-w-md` ... (spacing scale, fractions `w-1/2`, `full`, `screen`), `aspect-square` `aspect-video` `aspect-[4/3]` |
| Typography | `text-xs` ... `text-9xl`, `text-center`, `text-{color}`, `font-bold` ..., `font-mono`, `italic`, `underline`, `line-through`, `truncate`, `line-clamp-2` |
| Backgrounds | `bg-{color}` `bg-gradient-to-r` `from-*` `via-*` `to-*` `bg-[url(file.png)]` `bg-cover` `bg-contain` `bg-center` `bg-no-repeat` ... |
| Borders | `border` `border-2` `border-t` ... `border-{color}` `border-t-{color}` ... `border-dashed` `rounded` `rounded-lg` `rounded-full` `rounded-t-xl` ... `divide-y` `divide-x` `divide-{color}` |
| Shadows | `shadow-sm` `shadow` `shadow-md` `shadow-lg` `shadow-xl` `shadow-2xl` `shadow-inner` `shadow-none` `shadow-{color}` |
| Transforms | `translate-x-*` `-translate-y-1/2` `rotate-45` `scale-105` `scale-x-*` `skew-x-*` `origin-*` |
| Images | `object-cover` `object-contain` `object-fill` `object-center` ... |
| Rings | `ring` `ring-2` `ring-{color}` (composed with `shadow-*`) |
| Effects | `opacity-50` `transition` `transition-colors` `transition-opacity` `transition-transform` `transition-all` `duration-300` `delay-*` `ease-out` ... `animate-spin` `animate-ping` `animate-pulse` `animate-bounce` |
| Other | `cursor-*` `z-*` `overflow-x-auto` `overflow-y-auto` `scrollbar-none` `pointer-events-none` |

- Full Tailwind color palette (`slate` ... `rose`, shades `50` to `950`)
- Arbitrary values: `w-[200px]`, `bg-[#ff8800]`, `text-[13px]`, `bg-[length:60px_40px]`
- Opacity modifiers: `bg-black/50`, `text-white/70`, `border-slate-900/10`
- Variants: `hover:`, `active:`, `focus:`, `focus-within:`, `first:`, `last:`, `odd:`, `even:`, `group-hover:`,
  `dark:` (variants can be combined, for example `dark:hover:bg-slate-700`)
- Responsive variants `sm:` `md:` `lg:` `xl:` `2xl:` use the width of the `TCSSShape` control, so they act
  like container queries
- Utility classes can be mixed with a regular stylesheet. Utilities are applied after stylesheet rules.

Not supported yet: `divide-dashed`, negative `space-*`, `backdrop-blur`.

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

## Icons

Copy an icon on [lucide.dev](https://lucide.dev) (*Copy SVG*) and paste it into the markup. Size comes from
classes (or `width`/`height`), color is the text color (`currentColor`):

```pascal
CSSShape1.Body.AppendHTML(
  '<div class="flex items-center gap-2 text-sky-600">' +
  '  <svg class="size-5" viewBox="0 0 24 24" stroke-width="2"><path d="M20 6 9 17l-5-5"/></svg>' +
  '  Saved' +
  '</div>');
```

The engine paints stroked shapes (`path`, `line`, `polyline`, `polygon`, `rect`, `circle`, `ellipse`) with
round caps and joins, antialiased and cached, the same way on every platform. No font file and no library
are needed. Fills, `<g>` transforms and other SVG features are not supported. Lucide icons are under the
ISC License, keep its notice when you copy them (see `demo/kanban/kanbanicons.pas`).

## Animations

Minimal on purpose, there is no `@keyframes` parser:

- `transition` (`transition-property`, `-duration`, `-timing-function`, `-delay`) animates colors (background,
  text, borders), `opacity` and `transform` when styles change, for example on hover, focus or when classes
  are changed from code. Timing functions: `linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out`,
  `cubic-bezier()`.
- Built-in animations of Tailwind CSS: `animation: spin | ping | pulse | bounce <duration>`
  (`animate-spin` ...), for spinners, notification dots, loading skeletons.
- Animations change only painted values, the layout is not recalculated. `TCSSShape` runs a timer only while
  something is animated and repaints only the animated area.
- Not animated: `box-shadow` (changes at once), sizes and positions from layout, text color inherited by
  children.
- `opacity` below 1 and scaled or rotated nodes are painted through a bitmap. The bitmap of the node is
  rendered once per animation and then only resampled, so a fade or spin is cheap. For muted text, a color
  with alpha (`text-white/70`) is still cheaper than `opacity-70`.

## Dark mode

Add `dark:` classes and switch the mode for all `TCSSShape` controls:

```pascal
Card.SetClass('p-6 rounded-xl bg-white dark:bg-slate-900 text-slate-900 dark:text-white transition-colors');
CSSSetDarkMode(True);     // styles are applied again, changes with transition are animated
```

Native LCL controls (`TEdit` ...) keep their own colors, set them in code when the mode is changed.

## Components and form designer

`csscomponents.pas` (palette page *CSS*) contains ready made components: `TCSSButton` (`Caption`, `Kind`),
`TCSSToggle` (animated switch, `Checked`, `OnChange`), `TCSSBadge`, `TCSSAvatar` (initials or image) and
`TCSSTabs` (segmented control, `Tabs`, `TabIndex`, `OnChange`; the indicator moves with a transition, many
tabs scroll horizontally). They are normal Lazarus components, each one
only sets utility classes of its nodes, so it is also an example for own components (about 50 lines each).
The unit enables utility classes itself (`CSSTailwindEnable` in its initialization, unless the application
set its own resolver), so the components look the same at runtime as in the form designer.

```pascal
Btn := TCSSButton.Create(Self);
Btn.Parent := Self;
Btn.SetBounds(16, 16, 100, 36);
Btn.Caption := 'Delete';
Btn.Kind := cbkDanger;
Btn.OnClick := @DeleteClick;
```

`TCSSShape` has `HTML`, `CSS` and `BodyClass` properties, so content can be written in the Object Inspector
and is shown in the form designer (the package enables utility classes in the IDE). At runtime the shape enables
utility classes itself when it gets this markup (`CSSTailwindEnable`, unless the application set its own resolver),
so it looks the same as in the designer. Nodes from the markup are found by id:

```pascal
CSSShape1.Body.GetElementById('save').OnClick := @SaveClick;
```

## LCL controls in nodes

Inputs are real LCL controls placed in nodes, so their values and events are the usual ones:

```pascal
Edit := TEdit.Create(Self);
Edit.Parent := Self;
Edit.BorderStyle := bsNone;               // the node draws the rounded border, ring and so on
Edit.OnChange := @PhoneChange;            // validate while typing
Node.SetAlignControl(Edit);               // Node is a styled wrapper, eg. found by GetElementById
...
S := TEdit(Node.AlignControl).Text;      // read the value
```

Nodes created from markup are found with `GetElementById` or `GetElementsByClassName`, clicks are handled
with `Node.OnClick`. To change the look, change classes (`Node.SetClass(...)`) and call `ApplyStyles` and
`Changed` of the shape. Changed values are animated when the node has a `transition`.

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

- `demo/csscontrols_demo.lpi`: demo application with several scenes: cards, buttons, flexbox, responsive
  layout, typography, dashboard, stylesheet, borders, backgrounds, shadows, HTML, transforms, drop zone,
  and app-like UIs (chat, settings, shop, calendar). The Forms scene shows LCL inputs (`TEdit`, `TMemo`)
  inside styled nodes and a dropdown painted by the renderer, which shows its items in a `TPopupMenu`.
  The demo application builds these from `data-lcl` attributes in the markup. Toggles and selections are
  wired the same way with `data-active` and `data-group`. *Inspect (debug)* turns on the inspect mode.
  The Grid scene shows a bento layout with spans, the Animations scene transitions and built-in animations,
  the Buttons scene CSS-only tooltips, the Utilities scene `space`, `divide`, `line-clamp`, `aspect`,
  `sticky` and `shadow-inner`. The *Components* scene shows LCL controls in nodes and the components of
  `csscomponents.pas`, the *Data table* scene 1000 rows. *Dark mode* switches the `dark:` variant: Settings,
  Dashboard, Utilities, Components and Data table have own `dark:` classes, other scenes get them from a
  small demo helper (`AddDarkVariants`) which adds dark variants of common light classes.
- `demo/kanban/kanban.lpi`: Kanban board application (see screenshots). Cards are moved by drag and drop:
  the dragged card is a small `TCSSShape` above the board, the placeholder is moved in the board by
  `InsertBefore`. The detail dialog uses native controls, tasks are saved to `tasks.json` in
  the application config folder.
- `demo/renderdemo.lpi`: renders the demo scenes to PNG files, which is handy for checking changes visually
  (`renderdemo out 720 Borders 4` renders one scene zoomed 4x, `renderdemo bench` measures paint time)
- `tests/csstests.lpi`: fpcunit tests (console runner)

```sh
lazbuild tests/csstests.lpi && tests/csstests
lazbuild demo/renderdemo.lpi && demo/renderdemo demo/out 720
```

## Limitations

- Delphi/FMX is not supported yet. Some code paths exist, but they are incomplete.
- `position: sticky` works vertically (`top`), `line-clamp` cuts text at whole words.
- Native LCL controls are always painted above the CSS content, so a dropdown drawn by the renderer can't
  overlap a `TEdit`.
- `overflow: hidden` clips by a rectangle. Only children touching the rounded corners are rounded, so
  scrolled content inside a rounded container is not clipped by the corners.
- Scaled and rotated nodes and nodes with `opacity` below 1 are painted through a bitmap. Content
  overflowing the node (except shadows) is clipped. For large panels prefer `translate` (painted directly)
  to `opacity` or `scale` (a bitmap in device resolution, several MB for a big dialog on Retina).
- `z-index` orders siblings only (no stacking contexts), so a popup should be the last child or have a
  higher `z-index` than siblings which overlap it.
- Colors with alpha are blended with the nearest background color for text and borders. Backgrounds
  use a real alpha channel.
- Under a node with a transparent or semi-transparent background the shadow can be seen through the
  background (browsers paint outer shadows only outside of the node). Under an opaque background the
  shadow is not painted at all.

## Performance

Painting is done with the LCL canvas only, no extra libraries are used:

- Hover, active and focus states apply styles only to changed nodes. Layout is computed only when sizes
  change, a hover which changes colors only repaints the changed area. Nodes outside the visible area are
  skipped when painting. The *Data table* scene (1000 rows, more than 5000 nodes) needs about 1.5 ms per
  mouse move and 2 ms per paint.
- Sizes of nodes are cached during one layout pass. Nested flex containers lay out their items several
  times (hypothetical size, flexed size, stretched size), without the cache the work grows exponentially
  with depth. The Kanban demo (about 400 nodes, 9 levels of flex) needs 5 ms per layout instead of 100 ms.
- Something which moves with the mouse (a dragged card) can be a small `TCSSShape` above the main one:
  moving it with `SetBounds` repaints only the area under it, the main shape is not laid out again.
- Memory: the cache of corner and icon bitmaps is limited, bitmaps of colors in a transition are not
  cached, bitmaps of scaled, rotated and transparent nodes are released when they are painted directly
  again. The Kanban demo needs about 90 MB on macOS when idle (Activity Monitor), a third of it is the
  window buffer of the system. While something animates, macOS keeps more window buffers (about 70 MB
  more for a large Retina window), they are released when the window is idle.
- When many nodes are created in code, call `CSSBeginUpdate` before and `CSSEndUpdate` and `Changed` of the
  shape after, so the layout is computed once (`AppendHTML` does it itself).

- Straight parts of backgrounds and borders are drawn with `FillRect`.
- Background images and horizontal or vertical gradients are drawn with `StretchDraw`.
- Rounded corners, border joins and diagonal gradients are rasterized with antialiasing into small bitmaps,
  which are cached. Equal corners of different nodes share one bitmap.
- Shadows are cut into 9 cached parts (corners, edges, center), so their cost doesn't depend on node size.
  Under a node with an opaque background, only the parts of the shadow outside the node are painted.
- So a big node (for example a full window panel) with a solid background, rounded corners and a shadow
  costs a few `FillRect` calls plus small cached bitmaps. Nothing of the size of the node is rendered or
  stored. Full size bitmaps are used only for diagonal gradients, `opacity` below 1 and scaled or rotated
  nodes.
- Bitmaps are rendered in device resolution (2x on macOS Retina).

`demo/renderdemo resize` measures painting while a window is being resized.
- Text inside a node is laid out as one block (no inline formatting across nodes).

## License

Apache License 2.0, see [LICENSE](LICENSE).

The color palette in `csstailwind.pas` comes from Tailwind CSS, Copyright (c) Tailwind Labs, Inc.,
MIT License. This project is not affiliated with Tailwind Labs.

Icons in the Kanban demo and in the architecture picture come from [Lucide](https://lucide.dev),
ISC License, Copyright (c) Lucide Icons and Contributors (some derived from Feather, MIT License,
Copyright (c) 2013-present Cole Bemis). The license text is in `demo/kanban/kanbanicons.pas`.
