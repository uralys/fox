# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

func setup():
  if(G.ENV == G.RELEASE):
    for option in options:
      self[option] = false

    G.log('✅ debug options deactivated in production');
    return

  var debugOptionsEnabled = false

  for option in options:
    if(self[option]):
      G.log(' >', option, '[color=pink]is activated [/color]')
      debugOptionsEnabled = true

  if(not debugOptionsEnabled):
    G.log('👾 ✅ options deactivated, same as production');
