extends CanvasLayer

# ------------------------------------------------------------------------------

signal introFinished

# ------------------------------------------------------------------------------

@onready var logo = $logo
@onready var letters = $letters

@onready var U = $letters/u
@onready var R = $letters/r
@onready var A = $letters/a
@onready var L = $letters/l
@onready var Y = $letters/y
@onready var S = $letters/s
@onready var DOT = $letters/dot

# ------------------------------------------------------------------------------

func _ready():
  G.log('> intro animation');
  G.log('-------------------------------')
  logo.hide()
  letters.hide()

  await Wait.forSomeTime(self, 0.25).timeout
  Animate.show(logo, 0.75)

  letters.show()
  Animate.show(U, 1.5, 0.15)
  Animate.show(R, 1.5, 0.25)
  Animate.show(A, 1.5, 0.35)
  Animate.show(L, 1.5, 0.15)
  Animate.show(Y, 1.5, 0.25)
  Animate.show(S, 1.5, 0.15)
  Animate.show(DOT, 1.5, 0.15)

  await Wait.forSomeTime(self, 2).timeout


  Animate.hide(logo, 0.5)
  Animate.hide(U, 0.5, 0.15)
  Animate.hide(R, 0.5, 0.25)
  Animate.hide(A, 0.5, 0.4)
  Animate.hide(L, 0.5, 0.25)
  Animate.hide(Y, 0.5, 0.15)
  Animate.hide(S, 0.5, 0.1)
  Animate.hide(DOT, 0.5, 0.05)

  await Wait.forSomeTime(self, 0.9).timeout
  exitIntro()

# ------------------------------------------------------------------------------

func exitIntro():
  emit_signal('introFinished')
  get_parent().remove_child(self)
  queue_free()

# ------------------------------------------------------------------------------

