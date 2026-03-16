package core {

	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;

	public class World {

		private static const TICK_MAX:int = 30;
		private static const TICK_DEPTH_SORT:int = 2;
		private static const TICK_SPECIAL_DEPTH:int = 6;
		private static const TICK_COMBAT_QUEUE:int = 2;
		private static const TICK_BOOST:int = 150; // ~5s at 30 FPS | 5s * 30 = 150

		private static const arrQuality:Array = ["LOW", "MEDIUM", "HIGH"];

		public function World(main:*) {
			this.main = main;
		}

		private var main:*;

		private var _tickDepthSort:int = 0;
		private var _tickSpecialDepth:int = 0;
		private var _tickCombatQueue:int = 0;
		private var _tickBoost:int = 0;

		private var fpsTS:Number = 0;
		private var fpsQualityCounter:int = 0;
		private var fpsArrayQuality:Array = [];

		private var tickSum:Number = 0;
		private var tickList:Array = [];

		private var combatDisplayTime:uint;

		private function get game():MovieClip {
			return main.gameMovieClip;
		}

		public function onEnterFrame(event:Event):void {
			if (game == null || game.world == null) {
				return;
			}

			// High priority
			calculateFPS();

			// High priority
			if (++_tickDepthSort >= TICK_DEPTH_SORT) {
				_tickDepthSort = 0;
				sortCharactersByDepth();
			}

			// Low priority
			if (++_tickSpecialDepth >= TICK_SPECIAL_DEPTH) {
				_tickSpecialDepth = 0;
				enforceSpecialMapDepth();
			}

			// Low priority
			if (++_tickBoost >= TICK_BOOST) {
				_tickBoost = 0;
				checkAndRenewBoosts();
			}

			// High priority
			if (++_tickCombatQueue >= TICK_COMBAT_QUEUE) {
				_tickCombatQueue = 0;
				processCombatDisplayQueue();
			}
		}

		private function calculateFPS():void {
			if (fpsTS != 0) {
				const fpsTime:int = new Date().getTime() - fpsTS;

				var removed:Number = 0;

				if (tickList.length == TICK_MAX) {
					removed = tickList.shift();
				}

				tickList.push(fpsTime);
				tickSum = (tickSum + fpsTime) - removed;

				var tickFinal:Number = 1000 / (tickSum / tickList.length);

				if (game.ui && game.ui.mcFPS && game.ui.mcFPS.visible) {
					game.ui.mcFPS.txtFPS.text = tickFinal.toPrecision(3);
				}

				if (++fpsQualityCounter % TICK_MAX == 0 && tickList.length == TICK_MAX && game.userPreference && game.userPreference.data && game.userPreference.data.quality == "AUTO") {
					fpsArrayQuality.push(tickFinal);

					if (fpsArrayQuality.length == 5) {
						var quality:Number = 0;

						for (var i:int = 0; i < fpsArrayQuality.length; i++) {
							quality += fpsArrayQuality[i];
						}

						const qualityFinal:Number = quality / fpsArrayQuality.length;
						const qualityIndex:int = arrQuality.indexOf(game.stage.quality);

						if (qualityFinal < 12 && qualityIndex > 0) {
							game.stage.quality = arrQuality[(qualityIndex - 1)];
						}

						if (qualityFinal >= 12 && qualityIndex < 2) {
							game.stage.quality = arrQuality[(qualityIndex + 1)];
						}

						fpsArrayQuality = [];
					}
				}
			}

			fpsTS = new Date().getTime();
		}

		private function sortCharactersByDepth():void {
			if (game.world.CHARS == null) {
				return;
			}

			var entries:Array = [];
			var displayObject:DisplayObject;

			for (var i:int = 0; i < game.world.CHARS.numChildren; i++) {
				displayObject = game.world.CHARS.getChildAt(i);

				entries.push({
					dio: displayObject,
					oy: displayObject.y
				});

				displayObject = null;
			}

			entries.sortOn("oy", Array.NUMERIC);

			var child:MovieClip;
			var currentIndex:int;

			for (var j:int = 0; j < entries.length; j++) {
				child = entries[j].dio;
				currentIndex = game.world.CHARS.getChildIndex(child);

				if (currentIndex != j) {
					game.world.CHARS.swapChildrenAt(currentIndex, j);
				}

				child = null;
			}

			entries = null;
		}

		private function enforceSpecialMapDepth():void {
			if (game.world.strFrame != "Enter") {
				return;
			}

			switch (game.world.strMapName) {
				case "trickortreat":
					bringToFront("mcPlayerNPCTrickOrTreat");
					break;
				case "caroling":
					bringToFront("mcPlayerNPCCaroling");
					break;
			}
		}

		private function bringToFront(npcName:String):void {
			if (game.world.CHARS == null) {
				return;
			}

			const target:DisplayObject = game.world.CHARS.getChildByName(npcName);

			if (target) {
				game.world.CHARS.setChildIndex(target, game.world.CHARS.numChildren - 1);
				return;
			}

			try {
				const firstMonster:* = game.world.getMonsters(1)[0].pMC;

				if (firstMonster) {
					game.world.CHARS.setChildIndex(firstMonster, game.world.CHARS.numChildren - 1);
				}
			} catch (e:Error) {
			}
		}

		private function checkAndRenewBoosts():void {
			if (game.stage == null) {
				try {
					game.world.killTimers();
					game.world.killListeners();
				} catch (e:Error) {}
				return;
			}

			if (game.ui == null || game.ui.mcPortrait == null) {
				return;
			}

			if (game.world.myAvatar == null || game.world.myAvatar.objData == null) {
				return;
			}

			const now:Number = new Date().getTime();
			const portrait:MovieClip = game.ui.mcPortrait;

			checkBoost(now, portrait.iconBoostXP, "iBoostXP", "xpboost");
			checkBoost(now, portrait.iconBoostG, "iBoostG", "gboost");
			checkBoost(now, portrait.iconBoostRep, "iBoostRep", "repboost");
			checkBoost(now, portrait.iconBoostCP, "iBoostCP", "cpboost");
		}

		private function checkBoost(now:Number, icon:*, boostKey:String, boostType:String):void {
			if (icon == null || game.world.myAvatar.objData[boostKey] == null) {
				return;
			}

			const expiresAt:Number = icon.boostTS + icon[boostKey] * 1000;

			if (expiresAt < now + 1000) {
				game.sfc.sendXtMessage("zm", "serverUseItem", ["-", boostType], "str", -1);
			}
		}

		private function processCombatDisplayQueue():void {
			if (!combatDisplayTime) {
				combatDisplayTime = new Date().time;
			}

			const now:uint = new Date().time;

			if (now - combatDisplayTime < 250) {
				return;
			}

			var didDisplay:Boolean = false;

			if (game.world.ActionResults && game.world.ActionResults.length > 0) {
				game.world.showActionImpact(game.world.ActionResults.shift());
				didDisplay = true;
			}

			if (game.world.ActionResultsAura && game.world.ActionResultsAura.length > 0) {
				game.world.showAuraImpact(game.world.ActionResultsAura.shift());
				didDisplay = true;
			}

			if (game.world.ActionResultsMon && game.world.ActionResultsMon.length > 0) {
				game.world.showActionImpact(game.world.ActionResultsMon.shift());
				didDisplay = true;
			}

			if (didDisplay) {
				combatDisplayTime = new Date().time;
			}
		}

	}
}
