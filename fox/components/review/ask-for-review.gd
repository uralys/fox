extends 'res://fox/components/popup.gd'

# ------------------------------------------------------------------------------

@onready var text: Label = $panel/text
@onready var rateLabel: Label = $panel/rateButton/label
@onready var rateButton = $panel/rateButton

# ------------------------------------------------------------------------------

var rateMe
var landscape = false

# ------------------------------------------------------------------------------

func _ready():
  text.text = tr('please rate this app')

  if(landscape):
    panel.position = Vector2((G.W - panel.size.x)/2, 80)

  super._ready()

  if Engine.has_singleton('GodotAndroidRateme'):
    rateMe = Engine.get_singleton('GodotAndroidRateme')
    rateMe.completed.connect(onRatingCompleted)
    rateMe.error.connect(onRatingError) # use err as string
    rateButton.visible = false
    closeButton.visible = false
    rateMe.show()

  elif Engine.has_singleton('InappReviewPlugin'):
    var iOSReview = $iOSReview
    iOSReview.connect('review_flow_launched', onRatingCompleted)
    iOSReview.launch_review_flow()

  else:
    rateLabel.text = tr('Rate now')
    rateButton.connect('pressed', showRateMe)

  Animate.from(panel, {
    propertyPath = 'position',
    fromValue = panel.position - Vector2(0, 300),
    transition = Tween.TRANS_QUAD,
    easing = Tween.EASE_OUT
  })

# ------------------------------------------------------------------------------

func showRateMe():
  if(Bundle.getPlatform() == 'iOS'):
    OS.shell_open('itms-apps://itunes.apple.com/app/' + Bundle.getAppId() + '?action=write-review')
  else:
    OS.shell_open(Bundle.getStoreUrl())

  onRatingCompleted()

# ------------------------------------------------------------------------------

func onRatingCompleted():
  Player.setRatingDone()
  close()

# ------------------------------------------------------------------------------

func onRatingError():
  close()

# ------------------------------------------------------------------------------

func useForLandscape():
  landscape = true
