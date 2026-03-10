package input {

	import flash.display.*;
	import flash.geom.*;

	public class WalkController {

		private static const SEND_EVERY_N_FRAMES:int = 5;
		private static const MOVE_SPEED_MULTIPLIER:Number = 8;

		public function WalkController(game:MovieClip, joystick:Joystick) {
			this.game = game;
			this.joystick = joystick;
		}
		
		private var game:MovieClip;
		private var joystick:Joystick;
		private var frameTick:int = 0;

		public function update():void {
			if (!game.world || !game.world.myAvatar) {
				return;
			}

			const pMC:MovieClip = game.world.myAvatar.pMC;

			if (pMC == null || (joystick.dirX == 0 && joystick.dirY == 0)) {
				return;
			}

			if (!game.world.isMoveOK(game.world.myAvatar.dataLeaf) || !game.world.bitWalk) {
				return;
			}

			const angle:Number = Math.atan2(joystick.dirY, joystick.dirX);
			const localX:Number = pMC.x + Math.cos(angle) * MOVE_SPEED_MULTIPLIER * 10;
			const localY:Number = pMC.y + Math.sin(angle) * MOVE_SPEED_MULTIPLIER * 10;

			const stagePt:Point = game.world.CHARS.localToGlobal(new Point(localX, localY));

			if (stagePt.x < 0 || stagePt.x > 960 || stagePt.y < 0 || stagePt.y > 550) {
				return;
			}

			const mvPT:Point = pMC.simulateTo(localX, localY, game.world.WALKSPEED);

			if (mvPT == null) {
				return;
			}

			pMC.walkTo(mvPT.x, mvPT.y, game.world.WALKSPEED);

			frameTick++;

			if (frameTick >= SEND_EVERY_N_FRAMES) {
				frameTick = 0;
				game.world.moveRequest({mc: pMC, tx: mvPT.x, ty: mvPT.y, sp: game.world.WALKSPEED});
			}
		}

		public function stop():void {
			frameTick = 0;

			if (game.world && game.world.myAvatar && game.world.myAvatar.pMC) {
				game.world.myAvatar.pMC.stopWalking();
			}
		}
	}
}

