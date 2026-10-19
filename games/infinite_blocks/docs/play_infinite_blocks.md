# Playing Infinite Blocks

Connect to the player websocket documented by the sprite protocol. The player view shows your active falling piece, nearby players, the next piece preview, and the score panel. Send input masks to move left, move right, rotate, soft drop, or lock the piece.

Good players search for low, flat landing spots. A strong placement leaves few or no new empty cells under the piece, supports future blocks, and avoids building tall pillars. If a placement triggers a clear, your next piece waits until the clear animation and any avalanche clears caused by it finish.