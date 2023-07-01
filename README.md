# grvl

dual data pavement for grid + norns/seamstress. no de-clicking, no interpolation, variable sample rate & bit depth.

a spiritual successor to [anaphora](https://github.com/andr-ew/prosody#anaphora).

## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) or macOS/linux, via [seamstress](https://github.com/ryleelyman/seamstress)
- [grid](https://monome.org/docs/grid/) (128 or 64)

**also supported**

- [crow](https://monome.org/docs/crow/)
- arc (2 or 4 rings)
- midi mapping

## install

(( not done yet don't install hehe ))

### norns

in the maiden [REPL](https://monome.org/docs/norns/image/wifi_maiden-images/install-repl.png), type:

```
;install https://github.com/andr-ew/grvl/releases/download/latest/complete-source-code.zip
```

### seamstress

see [grvl-seamstress](https://github.com/andr-ew/grvl-seamstress)

## grid

![diagram of the grid interface. text description forthcoming](/doc/grvl_grid.png)

TODO: silt (`enigne.head_offset`, 0-2)

## arc

| ch 1    | ch 1    | ch 2    | ch 2    |
| ------- | ------- | ------- | ------- |
| lvl     | fb      | lvl     | fb      |
| pm frq  | pm depth| pm frq  | pm depth|
| start   | end     | start   | end     |
| end     | rate    | end     | rate    |

horizontal & vertical orientation via arc focus component, hold two keys to flip

## norns

- E1: page/chan focus
- E2-E3:
  - lvl, pan
  - start, end
  - fb, rate
  - lp frq, lp q
- K2-K3 (hold) + other UI element: assign mod src 1/2
- K1 (hold) + K2-K3: assign mod sources

