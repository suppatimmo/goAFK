# goAFK
AFK Manager for CS:GO


## [PL]
Sprawdzanie AFK na 2 sposoby.
Pierwszy sprawdza ustawienie kamery gracza oraz jego pozycji, a drugi bazuje na wciśniętych klawiszach.

##### Instalacja :

scripting/goAFK.sp skompilować i umieścić w csgo/addons/sourcemod/plugins/

translations/goAFK.phrases.txt umieścić w csgo/addons/sourcemod/translations/

##### Cvary:
    goAFK_enabled = 1 włącza plugin / 0 wyłącza.

    goAFK_mode = tryb działania pluginu. 1 - AFK zostanie wyrzucony z serwera/ 2 - zostanie przeniesiony do SPECT.

    goAFK_kickSpect =  jeśli goAFK_mode jest 1, to czy sprawdzać również obserwatorów czy są AFK?

    goAFK_min = minimalna ilość graczy, aby plugin zaczął spełniać swoje zadania.

    goAFK_movetime = czas, po którym gracz zostanie przeniesiony do SPECT, jeśli goAFK_mode to 2.

    goAFK_kicktime = czas, po którym gracz zostanie wyrzucony, jeśli goAFK_mode to 1.

    goAFK_warntime = czas, po którym gracz zacznie otrzymywać ostrzeżenia o byciu AFK.

    goAFK_disablestrafe = 1 włącza opcję sprawdzania po klawiszach (dedykowane cwaniakom +left, +forward) / 0 wyłącza ją.

    goAFK_excludeBots = 1 wyłącza BOT'y ze wszelkich działań pluginu prócz liczenia graczy / 0 zalicza je.

    goAFK_adminimmune = nadaje immunitet dla adminów przed działaniem pluginu. 0 - brak immunitetu / 1 - pełny immunitet / 2 immunitet na wyrzucenie z gry / 3 immunitet na przerzucenie do SPECT

    goAFK_adminflag = flaga, która upoważnia do immunitetu przed działaniem pluginu.  >> FLAGI TUTAJ << . Puste miejsce oznacza, że wystarczy jakakolwiek flaga.

## [EN]


Checking AFK's in 2 ways.
The first way is checking clients eye and body position, and the second is based on the pressed keys.

##### Installation : 

compile scripting/goAFK.sp, and put in csgo/addons/sourcemod/plugins/

place translations/goAFK.phrases.txt  in csgo/addons/sourcemod/translations/

##### Cvars:

    goAFK_enabled = 1 - ON / 0 - OFF

    goAFK_mode = 1 - KICK / 2 - MOVE TO SPECT

    goAFK_kickSpect = If goAFK_mode - 1, include spectators to checkin' if AFK?

    goAFK_min = Minimum amount of players to enable plugin actions

    goAFK_movetime = Time to move player

    goAFK_kicktime = Time to kick player

    goAFK_warntime = Time to warn player    

    goAFK_disablestrafe = 1, if you want to include +left, +right afk guys to kick

    goAFK_excludeBots = Exclude bots from plugin actions? 1 - exclude / 0 - include

    goAFK_adminimmune = 0 - no immunity for admins / 1 - complete immunity for admins / 2 - immunity for kick AFK admins / 3 - immunity for moving AFK admins

    goAFK_adminflag = Admin flag for immunity, blank - any flag
