package bot.module {

	import flash.utils.getQualifiedClassName;

	/**
	 * Quest Item Rates module - shows drop rate percentages in the quest UI.
	 * Shows drop rate percentages next to quest reward items in the quest UI.
	 * Enabled by default.
	 */
	public class QuestItemRates extends Module {

		public function QuestItemRates() {
			super("QuestItemRates");
			enabled = true;
		}

		override public function onFrame(game:*):void {
			if (game == null || game.ui == null || game.ui.ModalStack == null) return;

			var modalStack:* = game.ui.ModalStack;
			if (modalStack.numChildren == 0) return;

			var cFrame:* = modalStack.getChildAt(0);
			if (getQualifiedClassName(cFrame) != "QFrameMC") return;
			if (!cFrame.cnt || !cFrame.cnt.core || !cFrame.cnt.core.rewardsRoll) return;

			var rewardsRoll:* = cFrame.cnt.core.rewardsRoll;
			var rewardList:* = cFrame.qData.reward;

			for (var i:int = 1; i < rewardsRoll.numChildren; i++) {
				var rew:* = rewardsRoll.getChildAt(i);
				if (rew.strType == null || rew.strType.text == null) continue;

				// Skip if already has percentage appended
				if (rew.strType.text.indexOf("%") != -1) continue;

				for each (var r:* in rewardList) {
					if (r.ItemID == rew.ItemID &&
						(!rew.strQ.visible || r.iQty.toString() == rew.strQ.text.substring(1))) {
						rew.strType.text += " (" + r.iRate + "%)";
						rew.strType.width = 100;
						rew.strRate.visible = false;
					}
				}
			}
		}
	}
}
