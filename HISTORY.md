# Racing+ Mod Version History

Note that the Racing+ Mod version will almost always match the client version. This means that the version number of the mod may increase, but have no actual new in-game changes. All gameplay related changes will be listed below.

* *0.2.61* - Unreleased
  * Maggy starts with the Soul Jar, a new passive item. (This is to make the R+14 speedrun category interesting.)
  * The Soul Jar has the following effects:
    * You no longer gain health from soul/black hearts.
    * You gain an empty red heart container for every 4 soul/black hearts picked up.
    * You always have a 100% devil deal chance if no damage is taken.
    * You always have a 9% devil deal chance if damage is taken.
* *0.2.59* - March 4th
  * Fixed the (vanilla) bug with Eden's Soul where it would not start off at 0 charges.
  * Crystal Ball is now seeded.
  * Portals are now seeded. (As a side effect of this, Portals will always spawn 5 enemies instead of 1-5 enemies.)
  * Mom's Hand and Mom's Dead hand will now immediately attack you if there is only one of them in the room.
  * Removed Mom's Hand from Devil Room #13.
* *0.2.58* - March 4th
  * Fixed some various bugs with the new crawlspace stuff.
  * Non-purchasable item pedestals in shops are now seeded.
* *0.2.57* - March 2nd
  * Made crawlspaces use normal room transition animations instead of the long fade.
  * Removed the Blank Card animation after you use it with teleportation cards.
  * Centered the Mega Maw in the single Mega Maw room on the Chest (#269).
  * Added a door to the double Mega Maw room on the Chest (#39).
  * Fixed the (vanilla) bug where the door opening sound effect would play in crawlspaces.
  * Fixed the bug where the Mega Blast placeholder was showing up in item pools instead of The Book of Sin.
* *0.2.55* - March 2nd
  * Greatly sped up the attack patterns of Wizoobs and Red Ghosts.
  * Removed invulernability frames from Lil' Haunts.
  * Cursed Eye is now seeded.
  * Broken Remote is now seeded.
  * Broken Remote is no longer removed from seeded races.
  * Fixed the bug with School Bag where items would have more charges than they were supposed to at the beginning of a race.
  * Fixed the bug where The Book of Sin did not show up in the School Bag.
  * Fixed the bug where the Mega Blast placeholder did not show up in the School Bag.
  * Fixed the bug where The Book of Sin would not count towards the Book Worm transformation.
  * Fixed the bug where The Polaroid / The Negative would not be removed sometimes.
  * Fixed the bug where if you consumed a D6 with a Void and then tried to consume another pedestal, it would sometimes duplicate that pedestal.
* *0.2.54* - February 28th
  * Fast-clear now works with puzzle rooms.
  * Fixed a Larry Jr. room that should not have an entrance from the top.
  * Added better save file graphics, thanks to Gromfalloon.
* *0.2.53* - February 27th
  * Holding R on Eden no longer kills her.
  * The "drop" button will now immediately drop cards and trinkets. (This won't happen if you have the School Bag, Starter Deck, Little Baggy, Deep Pockets, or Polydactyly.)
  * Fixed the Strength card on Keeper. Note that it will only permanently give you a coin container if you are at 0 or less base coin containers.
  * Fixed the crash that occured with School Bag when you swapped at the same time as picking up a new item.
  * You will no longer recieve the Polaroid and get teleported to Womb 1 if you arrive at the Void floor.
  * Removed the "use" animation from Telepills.
  * Fixed a Basement/Cellar room that had a chance to spawn empty because of stacked entities.
  * Added two new graphics for save files (fully unlocked and not fully unlocked).
* *0.2.49* - February 24th
  * Keeper now starts with the D6, Greed's Gullet, Duality, and 50 cents.
  * Fixed the bug with Keeper and Greed's Gullet where he would not be able to pick up health ups.
  * Teleport! is now seeded (per floor). This item is no longer removed in seeded races.
  * Undefined is now seeded (per floor). This item is no longer removed in seeded races.
  * Telepills is now seeded (per floor, separately from Teleport!).
  * Broken Remote is now banned during seeded races. (I forgot to do this initially.)
  * When you spawn a co-op baby, it will now automatically kill the baby and delete all item pedestals in the room.
  * When you use a Sacrifice Room to teleport directly to the Dark Room, it will instead send you to the next floor.
  * Fixed an unavoidable damage I AM ERROR room where you would teleport on top of a Spiked Chest.
  * Cleaned up the door placements on some miscellaneous I AM ERROR rooms to ensure that the player always teleports to an intended location.
  * Fixed the I AM ERROR room without any entrances.
  * Fast-clear has been recoded to fix the bug where the doors would open if you killed two splitting enemies at the same time.
  * The title screen has been updated to a beautiful new one created by Gromfalloon.
  * Fixed some more out of bounds entities.
  * Fixed an asymmetric Scarred Guts on a Womb/Utero L room (#757).
  * Fixed a Little Horn room (#1095) where there was only a narrow entrance to the top and bottom doors.
  * Deleted the 2x2 Depths/Necropolis with 2 Begottens (#422), since they automatically despawn due to a bug.
  * Fixed the bug where the damage cache was not properly updated after having Polyphemus and then picking up The Inner Eye or Mutant Spider.
  * Fixed an asymmetric Scarred Guts on a Womb/Utero L room (#757).
  * Fixed a Little Horn room (#1095) where there was only a narrow entrance to the top and bottom doors.
  * Pressing the reset button on Eden now instantly kills her. (It is not possible to fix the resetting bug in a proper way.)
* *0.2.29* - February 12th
  * Changed the double Forsaken room to have two Dark Uriels.
  * All Globins will permanently die upon the 5th regeneration to prevent Epic Fetus softlocks.
  * Knights, Selfless Knights, Floating Knights, Bone Knights, Eyes, Bloodshot Eyes, Wizoobs, and Red Ghosts no longer have invulernability frames after spawning.
* *0.2.27* - February 11th
  * Fixed a room with boils that can cause a softlock with no bombs or keys.
  * Fixed the double trouble room that softlocks if you have no bombs.
  * Added a bunch of splitting enemies to the fast-clear exception list.
  * Pedestal replacement no longer applies to shops. (It causes some weird behavior.)
  * If you arrive at the Void floor for any reason, you will be automatically given the Polaroid and sent to Womb 1.
* *0.2.20* - February 8th
  * Renamed the Jud6s mod to the Racing+ mod. This should still be considered alpha software. It contains all of the room changes from the Afterbirth version of the Jud6s mod, as well as things that were not in the Afterbirth version, like Wrath of the Lamb style room clear. The full list of changes are listed on [the main changes page](https://github.com/Zamiell/isaac-racing-mod/blob/master/CHANGES.md).
