# Racing+ Mod Changes

### Design Goals

In terms of what to change about the game, the mod has several goals, and attempts to strike a balance between them. However, certain things are prioritized. The goals are listed below in order of importance:

* to reward skillful play
* to make the game more fun to play
* to fix bugs and imperfections
* to keep the game as "vanilla" as possible

<br />

## List of Main Changes

#### 1) Character Changes

* All characters now start with the D6 (except for Keeper, who gets to keep his useful Wooden Penny).
* Certain characters have their health changed so that they can consistently take a devil deal.
  * Judas starts with half a red heart and half a soul heart.
  * Blue Baby starts with three and a half soul hearts.
  * Azazel starts with half a red heart and half a soul heart.
* Judas starts with a bomb instead of 3 coins. (Judas is the most common character to race, so he needs to be able to get Treasure Room pedestal items surrounded by rocks.)
* Keeper starts with Greed's Gullet, Duality, and 25 cents.

#### 2) Devil Room and Angel Room Changes

Devil Rooms and Angel Rooms without item pedestals in them have been removed.

#### 3) Item Removal

Some items with no effect at all are removed:

* the Karma trinket (all Donation Machines are removed on the BLCK CNDL seed)
* the Amnesia pill (all curses are removed on the BLCK CNDL seed)
* the ??? pill (all curses are removed on the BLCK CNDL seed)

#### 4) Cutscene Removal

Cutscenes are removed. (However, there is an option in the client to re-enable boss cutscenes for racers with cutscene skip muscle memory.)

#### 5) Animation Removal

Some useless animations are removed:

* cowering in the fetal position at the beginning of every floor
* jumping in a hole to the next floor
* going up the beam of light to the Cathedral
* entering a chest when going to The Chest or beating the game
* teleporting upwards

#### 6) Wrath of the Lamb style room clear

Room clear was incorrectly ported from Wrath of Lamb to Rebirth; doors are intended to open at the beginning of an enemy's death animation, not at the end. The Racing+ mod fixes this to be the way it was originally intended.

#### 7) Void Portal Removal

Void Portals will automatically be deleted.

#### 8) Room Fixes

Many rooms with unavoidable damage or bugs have been fixed or deleted.

<br />

## Additional Changes for Custom Rulesets

Occasionally, other modified rulesets are used for racing to spice things up:

#### Seeded

* All characters start with The Compass in addition to their other items.
* Teleport! and Undefined are removed from all item pools.
* The Cain's Eye trinket is removed from the game.

#### Dark Room

* 4 golden chests will now spawn at the beginning of the Dark Room (instead of red chests).
* We Need To Go Deeper! is removed from all item pools.

#### Mega Satan

* Pedestals for Key Piece 1 and Key Piece 2 are placed next to the Mega Satan door on both The Chest and the Dark Room.

<br />

## Individual Room Changes

The [technical specifics of all of the individual room changes are listed in a separate document](https://github.com/Zamiell/isaac-racing-mod/blob/master/CHANGES-ROOM.md), for those who care to know the nitty-gritty details.

## Other Minor Changes

* All item rerolls are now seeded per room, even if you purchase or touch the item.
* Book of Sin is now seeded.
* Lil Chest is now seeded.
* Book of Sin will now generate actual random pickups.
* Mystery Sack will now generate actual random pickups.
* Fixed the spelling of Humbling Bundle.
* The Polaroid or The Negative will be automatically removed depending on your run goal. By default, it will remove The Negative.
* The trapdoor or the beam of light will on W2 be automatically removed depending on your run goal. By default, it will remove the trapdoor.

If you want, you can change the run goal manually in your "save.dat" file, located in the "racing+_857628390" folder.
