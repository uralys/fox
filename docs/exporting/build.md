# building

## icons

- use `adaptive_icon_template.afdesign` to create the `1200x1200` icon.

- export it using the `ios` artboard, as `assets/icons/icon-square-1200x1200.png`

- use `generate-icons.sh` to create all redimensioned icons

```sh
> cd path/to/your/game
> ./fox/scripts/generate-icons.sh
```

### notes

- `assets/icons/` should have a `.gdignore`
- `assets/icons/generated` should be added to `.gitignore`

## \_build folder

`/_build` should be added to `.gitignore` and have a `.gdignore`

```sh
_build
├── .gdignore
├── _extracts
├── android
├── ios
├── osx
└── ...
```
