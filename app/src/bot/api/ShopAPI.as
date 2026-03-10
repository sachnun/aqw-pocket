package bot.api {

	import bot.GameAccessor;

	/**
	 * Shop API - provides shop item lookup and purchasing operations.
	 * Provides shop item lookup and purchasing operations.
	 */
	public class ShopAPI {

		/** Buy an item by name from the currently open shop. Optionally specify quantity. */
		public static function buyItemByName(name:String, quantity:int = -1):Boolean {
			var item:* = getShopItem(name);
			if (item == null) return false;

			var game:* = GameAccessor.game;
			if (quantity == -1) {
				game.world.sendBuyItemRequest(item);
			} else {
				var buyItem:Object = {};
				buyItem.iSel = item;
				buyItem.iQty = quantity;
				buyItem.accept = 1;
				game.world.sendBuyItemRequestWithQuantity(buyItem);
			}
			return true;
		}

		/** Buy an item by ID from the currently open shop. Optionally specify quantity. */
		public static function buyItemByID(id:int, shopItemID:int = -1, quantity:int = -1):Boolean {
			var item:* = getShopItemByID(id, shopItemID);
			if (item == null) return false;

			var game:* = GameAccessor.game;
			if (quantity == -1) {
				game.world.sendBuyItemRequest(item);
			} else {
				var buyItem:Object = {};
				buyItem.iSel = item;
				buyItem.iQty = quantity;
				buyItem.accept = 1;
				game.world.sendBuyItemRequestWithQuantity(buyItem);
			}
			return true;
		}

		/** Find a shop item by name in the current shop. Returns null if not found. */
		public static function getShopItem(name:String):* {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.shopinfo == null) return null;

			var lowerName:String = name.toLowerCase();
			for each (var item:* in game.world.shopinfo.items) {
				if (item && item.sName && item.sName.toLowerCase() == lowerName) {
					return getShopItemByID(item.ItemID, item.ShopItemID);
				}
			}
			return null;
		}

		/** Find a shop item by ItemID (and optionally ShopItemID). Returns null if not found. */
		public static function getShopItemByID(itemID:int, shopItemID:int = -1):* {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.shopinfo == null) return null;

			for each (var item:* in game.world.shopinfo.items) {
				if (item && item.ItemID == itemID && (shopItemID == -1 || item.ShopItemID == shopItemID)) {
					return item;
				}
			}
			return null;
		}

		/** Get all items in the currently open shop */
		public static function getShopItems():Array {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.shopinfo == null) return [];

			var items:Array = [];
			for each (var item:* in game.world.shopinfo.items) {
				if (item) {
					items.push({
						ItemID: item.ItemID,
						ShopItemID: item.ShopItemID,
						sName: item.sName,
						iCost: item.iCost,
						bCoins: item.bCoins,
						sDesc: item.sDesc,
						sType: item.sType,
						iLvl: item.iLvl
					});
				}
			}
			return items;
		}

		/** Check if a shop is currently open */
		public static function isShopOpen():Boolean {
			var game:* = GameAccessor.game;
			return (game.world != null && game.world.shopinfo != null && game.world.shopinfo.items != null);
		}

		/** Load a shop by ID */
		public static function loadShop(shopID:int):void {
			var game:* = GameAccessor.game;
			if (game.world == null) return;
			game.world.sendLoadShopRequest(shopID);
		}
	}
}
