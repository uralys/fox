# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

func setup():
  var _options = self.options if self.options else {}

  if(G.ENV == G.RELEASE):
    for option in _options:
      self[option] = false

    G.log('✅ debug options deactivated in production');
    return

  var debugOptionsEnabled = false

  for option in _options:
    if(self[option]):
      G.log(' >', option, '[color=pink]is activated [/color]')
      debugOptionsEnabled = true

  if(not debugOptionsEnabled):
    G.log('👾 ✅ options deactivated, same as production');
