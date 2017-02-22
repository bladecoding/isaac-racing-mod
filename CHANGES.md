# Racing+ Mod Changes

## Website

If you want to learn more about Racing+, you can visit [the official website](https://isaacracing.net). If you want to know the changes that are present in the in-game mod, read on.

<br />

## Design Goals

In terms of what to change about the game, the mod has several goals, and attempts to strike a balance between them. However, certain things are prioritized. The goals are listed below in order of importance:

* to reward skillful play
* to make the game more fun to play
* to fix bugs and imperfections
* to keep the game as "vanilla" as possible

<br />

## List of Main Changes

### 1) Character Changes

* All characters now start with the D6.
* Certain characters have their health changed so that they can consistently take a devil deal.
  * Judas starts with half a red heart and half a soul heart.
  * Blue Baby starts with three and a half soul hearts.
  * Azazel starts with half a red heart and half a soul heart.
* Judas starts with a bomb instead of 3 coins.
* Keeper starts with Greed's Gullet, Duality, and 50 cents.

### 2) Devil Room & Angel Room Changes

Devil Rooms and Angel Rooms without item pedestals in them have been removed.

### 3) Cutscene & Animation Removal

Cutscenes are removed. (However, there is an option in the client to re-enable boss cutscenes for racers with cutscene skip muscle memory.)

Additionally, some useless animations are removed:
* cowering in the fetal position at the beginning of every floor
* jumping in a hole to the next floor
* going up the beam of light to the Cathedral
* entering a chest when going to The Chest or beating the game
* teleporting upwards

### 4) Wrath of the Lamb style room clear

Room clear was incorrectly ported from Wrath of Lamb to Rebirth; doors are intended to open at the beginning of an enemy's death animation, not at the end. The Racing+ mod fixes this to be the way it was originally intended.

### 5) Room Fixes

Many rooms with unavoidable damage or bugs have been fixed or deleted.

<br />

## Other Minor Bug Fixes & Quality of Life Changes

* Pressing the reset button on Eden now instantly kills her. (It is not possible to fix the resetting bug in a proper way.)
* Void Portals will automatically be deleted.
* If you get the 5% Void teleport after defeating Mom, you will be automatically given the Polaroid and be sent to Womb 1.
* Some items with no effect at all are removed:
  * the Karma trinket (all Donation Machines are removed on the BLCK CNDL seed)
  * the Amnesia pill (all curses are removed on the BLCK CNDL seed)
  * the ??? pill (all curses are removed on the BLCK CNDL seed)
* Troll Bombs and Mega Troll Bombs now always have a fuse timer of exactly 2 seconds.
* Globins will permanently die upon the 5th regeneration to prevent Epic Fetus softlocks.
* Knights, Selfless Knights, Floating Knights, Bone Knights, Eyes, Bloodshot Eyes, Wizoobs, and Red Ghosts no longer have invulernability frames after spawning.
* All item rerolls are now seeded per room, even if you purchase or touch the item. (This doesn't apply to shops.)
* Book of Sin is now seeded.
* Lil Chest is now seeded.
* Book of Sin will now generate actual random pickups.
* Mystery Sack will now generate actual random pickups.
* Greed's Gullet will now properly work on Keeper. (As a side effect of this, the Strength card / the Magic Mushroom Liberty Cap proc will not give a coin container.)
* Fixed the bug where Tech X + Ipecac does not update the damage cache properly.
* Fixed the bug where Tech X + Chocolate Milk does not update the tear cache properly.
* Fixed the spelling of Humbling Bundle.
* Spawning a co-op baby will automatically kill the baby, return the heart to you, and delete all item pedestals in the room. (This is to prevent various co-op baby-related exploits.)
* Teleporting to the Dark Room via a Sacrifice Room will instead send you to the next floor. (This is to prevent exploiting races to The Lamb or Mega Satan.)
* The Polaroid or The Negative will be automatically removed depending on your run goal. By default, it will remove The Negative.
* The trapdoor or the beam of light on Womb 2 will be automatically removed depending on your run goal. By default, it will remove the trapdoor.

If you want, you can change the run goal manually in your "save.dat" file, located in the Racing+ mod folder. By default, this is located at:
```
C:\Users\[YourUsername]\Documents\My Games\Binding of Isaac Afterbirth+ Mods\racing+_dev\save.dat
```

<br />

## Additional Changes for Custom Rulesets

Historically, most speedruns and races have been unseeded with the goal of killing Blue Baby. However, there are other rulesets used:

### Seeded

* All characters start with The Compass in addition to their other items.
* All characters start with the School Bag (from Antibirth). (This is experimental and is subject to change.)
* Teleport! and Undefined are removed from all item pools. (These items are unseeded.)
* The Cain's Eye trinket is removed from the game.

### Diversity

* Each racer starts with the same 3 random passive items. (This is in addition to the character's original passive items and resources.)
* For additional information, see [the documentation for diversity races](https://github.com/Zamiell/isaac-racing-mod/blob/master/README-DIVERSITY.md).

### Dark Room

* 4 gold chests will now spawn at the beginning of the Dark Room (instead of red chests).
* We Need To Go Deeper! is removed from all item pools.

### Mega Satan

* Pedestals for Key Piece 1 and Key Piece 2 are placed next to the Mega Satan door on both The Chest and the Dark Room.

<br />

## Individual Room Changes

The [technical specifics of all of the individual room changes are listed in a separate document](https://github.com/Zamiell/isaac-racing-mod/blob/master/CHANGES-ROOM.md), for those who care to know the nitty-gritty details.

<br />
