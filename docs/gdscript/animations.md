# Animations

## Animate API

You can use `Animate.xxx` functions anywhere.

## doc WIP

Read `/fox/animations/animate.gd` for details on options

## API

- static func `from`(object, \_options)

- static func `to`(object, \_options):

- static func `toAndBack`(object, \_options):

- static func `show`(object, duration = 0.3, delay = 0):

- static func `hide`(object, duration = 0.3, delay = 0):

- static func `appear`(object, delay = 0):

- static func `disappear`(object, delay = 0):

- static func `bounce`(object):

- static func `swing`(object, \_options):

## Examples

```gd
Animate.to(yourObject, {
  propertyPath = 'position',
  toValue = Vector2(200, 200),
  duration = 0.5,
  easing = Tween.EASE_IN_OUT,
  delay = 0.3
})
```

```gd
# showing the car smoothly
Animate.show(car)

# then wait for 2 seconds
await Wait.forSomeTime(car, 2).timeout

# then moving the car to (200, 200)
Animate.to(car, {
  propertyPath = 'position',
  toValue = Vector2(200, 200),
  duration = 0.5
})
```
