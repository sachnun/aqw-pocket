package bot.module {

	/**
	 * Hide Players module - hides other players' characters, names, shadows, and pets.
	 * Hides other players' characters, names, shadows, and pets.
	 * Your own avatar remains visible.
	 */
	public class HidePlayers extends Module {

		public function HidePlayers() {
			super("HidePlayers");
		}

		override public function onToggle(game:*):void {
			if (game == null || game.world == null) return;

			var avatars:* = game.world.avatars;
			for (var id:* in avatars) {
				var avatar:* = avatars[id];
				if (!avatar.isMyAvatar && avatar.pMC) {
					avatar.pMC.mcChar.visible = !enabled;
					avatar.pMC.pname.visible = !enabled;
					avatar.pMC.shadow.visible = !enabled;
					if (avatar.petMC) {
						avatar.petMC.visible = !enabled;
					}
				}
			}
		}

		override public function onFrame(game:*):void {
			onToggle(game);
		}
	}
}
