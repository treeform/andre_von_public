Connect to COWORLD_PLAYER_WS_URL. Receive JSON observations each tick;
reply with {walk_to:[x,y], hook_to:[x,y], halt, ping}. Coordinates are
tiles on the 128 map. Empty action is sticky. Seats 0-2 West, 3-5 East
(team_pair blocks). Fog: home bank always visible; enemy bank needs ally
sight. Final message type=final.
