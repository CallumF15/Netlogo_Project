breed [ players player ]
breed [ flags flag ]
breed [ prisons prison ]
breed [ tree ]
breed [ flagRED ]
breed [ flagBLUE ]

;;;;;;;;;;;;;;;
;; Variables ;;
;;;;;;;;;;;;;;;

globals [
  action       ;; Last button pressed. (Include if we want user to play)
  jailed?        ;; is the A.I in jail?
  lives        ;; how many lifes left
  time-left    ;; time remaining to end of game
  red-score       ;; Red teams score
  blue-score       ;; Blue teams score
  winning-score    ;; Score required to win
  blue-prison      ;; blue prison occupancy
  red-prison       ;; red prison occupancy
  players-prison    ;; score required to lose
  idValue
  opponentColor
  teamColor
]

players-own [
  team
  speed
  time
  state ;; defines what kind of behaviour the turtle has e.g Alert, capturing flag, defending flag
  target
  path
  path-points
  playerDirection
  in-prisoned
  previousState
  stateChanged
  hasFlag
  id
]

patches-own [
  default-color
]

__includes [ "navmesh.nls" "pathfinding.nls" "navigation.nls" "navigation demo.nls" "flagRelated.nls" "scoreRelated.nls" "stateRelated.nls" "setStateRelated.nls" ]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup

  clear-all
  reset-ticks
  set-default-shape tree "tree"
  set-default-shape flagRED "flag"
  set-default-shape flagBLUE "flag"
  set-default-shape prisons "circle 2"
  set-default-shape players "person"

;  setup-patches
;  setup-navmesh
;  setup-pathfinding
   setup-patches

  ifelse navigation-demo? [
    create-trees
    setup-navmesh
    setup-pathfinding
    setup-navigation-demo
  ] [
    set redBool false
    set blueBool false
    ask players [ set hasFlag false ]
    setup-flags
    setup-players
    create-jails
    create-trees
    set-player-id
    ;;navmesh & pathfinder under here
    setup-navmesh
    setup-pathfinding
;    setup-patches
    set-startGame-state
  ]

end


to setup-patches
  ask patches [
    set pcolor green
    set default-color green
  ]
  ask patches with [pxcor <= 17 and pxcor >= 15] [
    set pcolor 107
    set default-color 107
  ]
end

to-report random-between [ min-num max-num ]
    report random-float (max-num - min-num) + min-num
end



to setup-flags
  create-flagRED 1 [set color red
                 setxy random-between 2 5 random-between 2 30]
  ask flagRED [
    set redFlagSpawnPositionX xcor
    set redFlagSpawnPositionY ycor
  ]

  create-flagBLUE 1 [set color blue
                 setxy random-between 27 30 random-between 2 30]

   ask flagBLUE [
    set blueFlagSpawnPositionX xcor
    set blueFlagSpawnPositionY ycor
  ]
end



to setup-players

  create-players player-count [set color red
                  setxy random-between first ([xcor - 2] of flagRED) first ([xcor + 2] of flagRED) random-between first ([ycor - 2] of flagRED) first ([ycor + 2] of flagRED)]
  create-players player-count [set color blue
                  setxy random-between first ([xcor - 2] of flagBLUE) first ([xcor + 2] of flagBLUE) random-between first ([ycor - 2] of flagBLUE) first ([ycor + 2] of flagBLUE)]
end

to create-jails
  create-prisons 1 [set color red
                   setxy random-between (min-pxcor) 5 random-ycor]
  create-prisons 1 [set color blue
                   setxy random-between 27 (max-pxcor) random-ycor]
  ask prisons
  [set pcolor 32]
end

to create-trees
  create-tree tree-count [set color 53
                  setxy  random-between (min-pxcor) 14 random-ycor]
  create-tree tree-count [set color 53
                  setxy  random-between 18 (max-pxcor)  random-ycor]
  ask tree [if any? other turtles-here [die]]

  ask tree
  [set pcolor black]

end

to set-player-id
  set idValue 0

  ask players with [color = blue][
    if(id <= player-count / 2)[

      set idValue idValue + 1
      set id idValue
    ]
  ]

  set idValue 0

  ask players with [color = red][
       if(id <= player-count)[
      set idValue idValue + 1
      set id idValue
      ]
  ]
end



to go

  update-navmesh-display

  ask players [
    follow-path
    draw-path
  ]

  check-state-Changed
  ;;ask players [ if(timer > .2 and stateChanged = false)[ set stateChanged true  reset-timer] ]
  ask players [ if(timer > .2 and stateChanged = false)[ set stateChanged true  reset-timer] ]

  check-state Players with [color = blue]
  check-state Players with [color = red]
  set-state Players with [color = blue]
  set-state Players with [color = red]

  tick
end

to set-startGame-state ;;done

  let redPlayerCount count players with [color = red]
  let half redPlayerCount / 2
  let redCounter 0
  let blueCounter 0

  ask players with [color = red]
  [
    set redCounter redCounter + 1

    ifelse(redCounter > half)[
       set state "attackflag"
    ][ set state "wait" ]
  ]

  ask players with [color = blue]
  [
    set blueCounter blueCounter + 1
    ifelse(blueCounter > half)[
        set state "attackflag"
    ][ set state "wait" ]
  ]


end

to check-state-changed ;;checks to see if the current player state has changed

  ask players[

    if(state = previousState)[
      set stateChanged false
    ]

    if(previousState != state)[
      set stateChanged true
      set previousState state ;;if state hasn't changed, why assign it to previousState?
      output-show(word "stateChanged " stateChanged)
    ]
  ]

end

to revert-state [player states];;sets state back to last state

ask player with [state = states][
  if(state != previousState)[ ;;make sure its not the same
    set state previousState
  ]
]

end

to set-state[player]

    ifelse(any? player with [color = red])[ ;;assigns teamColor/opponentColor
       set opponentColor blue
       set teamColor red
    ][ set opponentColor red
       set teamColor blue ]


    check-jail-evade player ;;below checks if enemy is touching player, set player to jail & if are near, player will evade
    check-can-free-teammate player ;;below checks if team-mate is in-radius of prison to free team-mates
    flag-pickup player ;;checks to see if any players picked up flag
    check-if-defendflag player ;;checks if teammates in-radius of flag-holder to determine if they should defned
    check-if-attack player
     check-should-defend-capturer player ;;below sets teammates to help flag-capturer
    check-retrieve-flag player ;;below checks if enemy has flag, if so set players to retrieve it


    flag-pickup player ;;checks to see if any players picked up flag
    check-should-defend-capturer player ;;below sets teammates to help flag-capturer
    check-retrieve-flag player ;;below checks if enemy has flag, if so set players to retrieve it
    check-if-defendflag player ;;checks if teammates in-radius of flag-holder to determine if they should defned
    flag-captured
    check-if-rescue player

end




to check-state[player]

 ask player[

if(stateChanged = true)[
 output-show (state)
  ;;default states

  if(state = "attackflag")[
    if(color = red)[
      set path get-path patch-here first [ patch-here ] of flagBLUE
    ]

    if(color = blue)[
       set path get-path patch-here first [ patch-here ] of flagRED
    ]
  ]

  if (state = "defendflag")[
       defend-flag
  ]

  ;;end default states

  if (state = "capture") [
    if(teamColor = red)[
      capture-flag
    ]

    if(teamColor = blue)[
      capture-flag
    ]
  ]

  if (state = "defendcapturer") [
    defend-capturer
  ]

  if (state = "lostflag") [
    ;;team on alert trying to locate flag taker (soon as it's took, some move back to flag default location to find taker)
    retrieve-flag player
  ]

  if (state = "evade") [
    move-evade player
  ]


  if (state = "rescue") [
    ;;save teamate from jail (be aimed at defenders or whoever is near the cell)
    if(color = red) [ set path get-path patch-here first [ patch-here ] of prisons with [color = blue ]]
    if(color = blue) [ set path get-path patch-here first [ patch-here ] of prisons with [color = red ]]
    release-player
  ]

  if(state = "freed")[
    if(color = red) [free-player red ]
    if(color = blue) [free-player blue]
  ]

  if (state = "jail") [ ;;this works
    set speed speed = 0
    imprison-player
  ]
 ]
 ]

 if(blueRespawnFlag = true)[ respawn-blue-flags ]
 if(redRespawnFlag = true)[ respawn-red-flags ]

end
@#$#@#$#@
GRAPHICS-WINDOW
276
12
715
472
-1
-1
13.0
1
9
1
1
1
0
0
0
1
0
32
0
32
1
1
1
ticks
30.0

BUTTON
8
10
71
43
setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
78
10
141
43
go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
10
54
182
87
player-count
player-count
2
8
6
2
1
NIL
HORIZONTAL

SWITCH
30
511
184
544
navigation-demo?
navigation-demo?
1
1
-1000

OUTPUT
727
10
1328
465
12

SWITCH
23
212
165
245
color-navmesh?
color-navmesh?
1
1
-1000

SWITCH
25
261
166
294
label-navmesh?
label-navmesh?
1
1
-1000

BUTTON
787
490
910
523
NIL
output-navmesh
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
925
490
1087
523
NIL
output-navmesh-matrix
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1098
491
1198
524
NIL
clear-output
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
199
512
291
545
NIL
select-goal
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
25
315
169
348
smooth-path?
smooth-path?
0
1
-1000

SLIDER
10
94
182
127
player-speed
player-speed
0
1
0.58
0.001
1
NIL
HORIZONTAL

SWITCH
30
358
149
391
draw-path?
draw-path?
0
1
-1000

BUTTON
674
490
772
523
NIL
output-path
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
142
182
175
tree-count
tree-count
0
256
91
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

Capture the Flag game in which both teams have to capture the flag and return it too their own base. The players also have to capture other players and send them to jail when they are defending their flags. The game ends when one player has captured their flag or when all the other players are thrown in jail.

## HOW IT WORKS

Both turtles are assigned to teams and have different states depending on which actions they can take. Each player has their own state and this is determined by certain conditions such as if an enemy is close to the player they will evade, or if one of their team mates pick up the flag and their nearby, they'll move to there position to assist with the flag capture or if the enemy has taken their flag some team mates will be assigned the task of retrieving their flag before its captured.

The forest layout is generated at the start of a game along with a navigation mesh for pathfinding. As the game is re-setup the layout is randomly generated each time giving different obstacles for the AI to navigate through as they try to capture the flag and avoid enemy AI.

## HOW TO USE IT

Pressing setup creates the game, go plays the game, player count sets up the number of players in the game. The player can also set up the number of trees in the game so you can have more obstacles for the players to navigate through or less obstacles making the terrain easier to navigate through. You can adjust the speed of the the players so you can see the state changes in the game.

SETUP - This setups the game enviroment in preparation for when the "GO" button is clicked

GO - Runs the game

PLAYER-COUNT (SLIDER) - Controls the amount of players in each team to be spawned into the game.

TREE-COUNT (SLIDER) - Controls the amount of trees that will be spawned into the game. (note: the more trees the game has, the more problems may occur)

COLOR-MESH (TOGGLE) -

LABEL-NAVMESH (TOGGLE) -

SMOOTH-PATH (TOGGLE) -

DRAW-PATH (TOGGLE) -

NAVIGATION-DEMO (TOGGLE) -


## THINGS TO NOTICE

How the levels enviroment differs everytime the setup button is clicked and when the sliders are adjusted to increase the trees and player count of the world.

How each player states change and how they react based on certain conditions.

## THINGS TO TRY

Change the number of players.
Change the speed of the players.
Change the number of trees.
Set up an navigation demo and then selecting a goal for the player to travel to.

## EXTENDING THE MODEL

Adding in squad tactics so that team members can work together rather than determining their own state based on what's around them.

## NETLOGO FEATURES

Pathfinding for players, the changing of many states and random between two numbers. The navigation of the AI throught the obstacles is one of the main features. Also random level generation is another feature. The changing of the player states as the game progresses is another important feature of our game.

## CREDITS AND REFERENCES

Members-

 * Mathew Mitchell
 * Mathew McGerty
 * Chinglong Law
 * Callum Flannagan


@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2-RC3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
