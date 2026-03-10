package ui {

	import flash.display.*;
	import flash.events.*;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.text.*;

	public class UpdateBanner extends Sprite {

		private static const W:Number   = 430;
		private static const H:Number   = 36;
		private static const BTN_W:Number = 80;
		private static const BTN_H:Number = 22;

		public function UpdateBanner(version:String, releaseUrl:String) {
			buildBackground();
			buildLabel(version);

			// Download
			const download:Sprite = buildButton("Download");
			download.x = W - (BTN_W + 8) * 2;
			download.y = 7;
			download.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				navigateToURL(new URLRequest(releaseUrl));
			});
			addChild(download);

			// Close
			const self:UpdateBanner = this;
			const close:Sprite = buildButton("Close");
			
			close.x = W - BTN_W - 8;
			close.y = 7;
			
			close.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (self.parent) {
					self.parent.removeChild(self);
				}
			});
			
			addChild(close);

			x = 960 - 10 - this.width;
			y = 10;
		}

		private function buildBackground():void {
			const bg:Shape = new Shape();
			bg.graphics.beginFill(0x111111, 0.85);
			bg.graphics.drawRoundRect(0, 0, W, H, 8);
			bg.graphics.endFill();
			bg.graphics.lineStyle(1, 0x888888, 0.5);
			bg.graphics.drawRoundRect(0, 0, W, H, 8);
			
			addChild(bg);
		}

		private function buildLabel(version:String):void {
			const tf:TextField = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", 11, 0xffffff, false, null, null, null, null, TextFormatAlign.LEFT);
			tf.selectable   = false;
			tf.mouseEnabled = false;
			tf.width  = 220;
			tf.height = H;
			tf.x = 10;
			tf.y = 10;
			tf.alpha = 0.85;
			tf.text = "Update available: " + version;
			
			addChild(tf);
		}

		private function buildButton(label:String):Sprite {
			const bg:Shape = new Shape();
			bg.graphics.beginFill(0x333333, 0.9);
			bg.graphics.drawRoundRect(0, 0, BTN_W, BTN_H, 6);
			bg.graphics.endFill();
			bg.graphics.lineStyle(1, 0x888888, 0.5);
			bg.graphics.drawRoundRect(0, 0, BTN_W, BTN_H, 6);

			const lbl:TextField = new TextField();
			lbl.defaultTextFormat = new TextFormat("_sans", 10, 0xffffff, true, null, null, null, null, TextFormatAlign.CENTER);
			lbl.selectable   = false;
			lbl.mouseEnabled = false;
			lbl.width  = BTN_W;
			lbl.height = BTN_H;
			lbl.y = 4;
			lbl.alpha = 0.85;
			lbl.text = label;

			const btn:Sprite = new Sprite();
			btn.addChild(bg);
			btn.addChild(lbl);
			btn.buttonMode    = true;
			btn.useHandCursor = true;
			
			return btn;
		}
		
	}
}
