package bot {

	import flash.display.MovieClip;
	import flash.utils.getQualifiedClassName;

	/**
	 * Generic game object accessor.
	 * Provides path-based access to any game object property or function.
	 *
	 * Usage:
	 *   GameAccessor.getObject("world.myAvatar.objData.iHP")
	 *   GameAccessor.setObject("world.myAvatar.objData.iHP", 99999)
	 *   GameAccessor.callFunction("world.moveToCell", "r2", "Left")
	 */
	public class GameAccessor {

		private static var _game:MovieClip;
		private static var _gameClass:Class;
		private static var _gameDomain:*;

		public static function init(game:MovieClip, domain:* = null):void {
			_game = game;
			_gameDomain = domain;
			_gameClass = null;
		}

		public static function get game():MovieClip {
			return _game;
		}

		/** Resolve a dot-separated path starting from game root */
		public static function getObject(path:String):* {
			return resolvePathString(_game, path);
		}

		/** Resolve a dot-separated path starting from the game class (static members) */
		public static function getObjectStatic(path:String):* {
			if (_gameClass == null && _gameDomain != null) {
				_gameClass = _gameDomain.getDefinition(getQualifiedClassName(_game)) as Class;
			}
			if (_gameClass == null) return null;
			return resolvePathString(_gameClass, path);
		}

		/** Get a property value by key from an object at the given path */
		public static function getObjectKey(path:String, key:String):* {
			var obj:* = resolvePathString(_game, path);
			return obj[key];
		}

		/** Set a property at the given dot-path */
		public static function setObject(path:String, value:*):void {
			var parts:Array = path.split(".");
			var varName:String = parts.pop();
			var obj:* = resolvePathArray(_game, parts);
			obj[varName] = value;
		}

		/** Set a property by key on an object at the given path */
		public static function setObjectKey(path:String, key:String, value:*):void {
			var obj:* = resolvePathString(_game, path);
			obj[key] = value;
		}

		/** Get an element from an array at the given path */
		public static function getArrayObject(path:String, index:int):* {
			var obj:* = resolvePathString(_game, path);
			return obj[index];
		}

		/** Set an element in an array at the given path */
		public static function setArrayObject(path:String, index:int, value:*):void {
			var obj:* = resolvePathString(_game, path);
			obj[index] = value;
		}

		/** Call a function at the given dot-path with arguments */
		public static function callFunction(path:String, ...args):* {
			var parts:Array = path.split(".");
			var funcName:String = parts.pop();
			var obj:* = resolvePathArray(_game, parts);
			var func:Function = obj[funcName] as Function;
			if (func == null) return null;
			return func.apply(null, args);
		}

		/** Call a function at the given dot-path with no arguments */
		public static function callFunction0(path:String):* {
			var parts:Array = path.split(".");
			var funcName:String = parts.pop();
			var obj:* = resolvePathArray(_game, parts);
			var func:Function = obj[funcName] as Function;
			if (func == null) return null;
			return func.apply();
		}

		/** Select a property from each element of an array at the given path */
		public static function selectArrayObjects(path:String, selector:String):Array {
			var obj:* = resolvePathString(_game, path);
			if (!(obj is Array)) return [];

			var array:Array = obj as Array;
			var result:Array = [];
			for (var i:int = 0; i < array.length; i++) {
				result.push(resolvePathString(array[i], selector));
			}
			return result;
		}

		/** Check if an object at the given path is null */
		public static function isNull(path:String):Boolean {
			try {
				return resolvePathString(_game, path) == null;
			} catch (ex:Error) {
			}
			return true;
		}

		/** Resolve a dot-separated path string on a root object */
		public static function resolvePathString(root:*, path:String):* {
			return resolvePathArray(root, path.split("."));
		}

		/** Resolve an array of path parts on a root object */
		public static function resolvePathArray(root:*, parts:Array):* {
			var obj:* = root;
			for (var i:int = 0; i < parts.length; i++) {
				obj = obj[parts[i]];
			}
			return obj;
		}
	}
}
