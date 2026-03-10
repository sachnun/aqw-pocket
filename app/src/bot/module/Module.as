package bot.module {

	/**
	 * Base module class for frame-based plugins.
	 * Modules are frame-based plugins that can be toggled on/off.
	 * Each module runs its onFrame() callback every frame when enabled.
	 */
	public class Module {

		public var name:String = "Module";
		public var enabled:Boolean = false;

		public function Module(name:String) {
			this.name = name;
		}

		/** Called when the module is toggled on or off */
		public function onToggle(game:*):void {
		}

		/** Called every frame while the module is enabled */
		public function onFrame(game:*):void {
		}
	}
}
