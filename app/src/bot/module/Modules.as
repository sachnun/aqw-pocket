package bot.module {

	import flash.events.Event;

	import bot.GameAccessor;

	/**
	 * Module registry and frame handler.
	 * Manages all registered modules and dispatches frame events to enabled ones.
	 */
	public class Modules {

		private static var _modules:Object = {};

		/** Get a module by name */
		public static function getModule(name:String):Module {
			return _modules[name];
		}

		/** Register a module */
		public static function registerModule(m:Module):void {
			_modules[m.name] = m;
		}

		/** Enable a module by name */
		public static function enable(name:String):void {
			var module:Module = getModule(name);
			if (module != null) {
				var toggle:Boolean = !module.enabled;
				module.enabled = true;
				if (toggle) {
					module.onToggle(GameAccessor.game);
				}
			}
		}

		/** Disable a module by name */
		public static function disable(name:String):void {
			var module:Module = getModule(name);
			if (module != null) {
				var toggle:Boolean = module.enabled;
				module.enabled = false;
				if (toggle) {
					module.onToggle(GameAccessor.game);
				}
			}
		}

		/** Toggle a module by name. Returns new enabled state. */
		public static function toggle(name:String):Boolean {
			var module:Module = getModule(name);
			if (module != null) {
				if (module.enabled) {
					disable(name);
				} else {
					enable(name);
				}
				return module.enabled;
			}
			return false;
		}

		/** Check if a module is enabled */
		public static function isEnabled(name:String):Boolean {
			var module:Module = getModule(name);
			return (module != null && module.enabled);
		}

		/** Get all registered module names */
		public static function getModuleNames():Array {
			var names:Array = [];
			for (var name:String in _modules) {
				names.push(name);
			}
			return names;
		}

		/** Frame handler - call every ENTER_FRAME for all enabled modules */
		public static function handleFrame(e:Event):void {
			var game:* = GameAccessor.game;
			if (game == null) return;

			for (var name:String in _modules) {
				var module:Module = _modules[name];
				if (module.enabled) {
					try {
						module.onFrame(game);
					} catch (err:Error) {
						// Silently skip erroring modules to avoid breaking the frame loop
					}
				}
			}
		}

		/** Initialize all built-in modules */
		public static function init():void {
			registerModule(new QuestItemRates());
			registerModule(new HidePlayers());
			registerModule(new DisableCollisions());
	
		}

		/** Disable all modules and clear registry */
		public static function dispose():void {
			for (var name:String in _modules) {
				var module:Module = _modules[name];
				if (module.enabled) {
					module.enabled = false;
					try {
						module.onToggle(GameAccessor.game);
					} catch (e:Error) {}
				}
			}
			_modules = {};
		}
	}
}
