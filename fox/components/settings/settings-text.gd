extends RefCounted

# ==============================================================================
# settings-text.gd — translation with a literal fallback, plus locale endonyms
# (fox/components/settings).
#
# Every label of the shared settings view is declared twice in its data: a
# translation `key` and a plain `text`. A project that ships a translations CSV
# gets its locale; a starter game that ships none would otherwise display the raw
# key ("settings.audio.music"), because Godot's `tr()` returns the key unchanged
# when no translation exists. `resolve()` is that single decision point.
#
# Used by every atom through `SettingsText.resolve(key, text)` — a static-only
# helper, never instantiated.
# ==============================================================================

# Native names of the locales a fox game is likely to ship. The picker shows the
# endonym, so a player who cannot read the current UI language still recognises
# their own — the reason faraday's switcher never displays "German".
const ENDONYMS := {
	'en': 'English',
	'fr': 'Français',
	'de': 'Deutsch',
	'es': 'Español',
	'it': 'Italiano',
	'pt': 'Português',
	'nl': 'Nederlands',
	'pl': 'Polski',
	'cs': 'Čeština',
	'hu': 'Magyar',
	'ro': 'Română',
	'tr': 'Türkçe',
	'ru': 'Русский',
	'uk': 'Українська',
	'el': 'Ελληνικά',
	'ar': 'العربية',
	'th': 'ไทย',
	'vi': 'Tiếng Việt',
	'id': 'Bahasa Indonesia',
	'ja': '日本語',
	'ko': '한국어',
	'zh': '中文',
	'sv': 'Svenska',
	'da': 'Dansk',
	'fi': 'Suomi',
	'nb': 'Norsk',
}

# Translate `key`, falling back to `fallback` when the project ships no
# translation for it (Godot returns the key itself in that case).
static func resolve(key: String, fallback: String = '') -> String:
	if key == '':
		return fallback
	var translated: String = TranslationServer.translate(key)
	if translated != key:
		return translated
	return fallback if fallback != '' else key

static func endonym(locale: String) -> String:
	var code: String = locale.split('_')[0].to_lower()
	return ENDONYMS.get(code, locale.to_upper())
