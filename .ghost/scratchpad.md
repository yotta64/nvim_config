# 📝 Lavagna: nvim configuration

Status: [ ] In corso

TODO: learn lua 🦉

TODO: lazygit integration
- [ ] raccogliere Task
- [ ] inviare commit
- [x] add task
- [ ] another task
- [ ] another task


## Appunti
Ghost.nvim cheatsheet
1. Gestione Progetti (GhostVault)

    - `:GhostInit` -> Inizializza un nuovo progetto nella cartella corrente.

    - `:GhostSwitch` -> Cambia progetto (con memoria della sessione).
    
    - `:GhostDelete` -> Elimina un progetto dal registro.

    - `:GhostNote` -> Apre la Lavagna (scratchpad.md) del progetto.

2. Gestione Note (GhostNotes)

    - `<leader>an` -> Add Note: Crea una nota sulla riga corrente o la apre se esiste.

    - `<leader>ak` -> Add Link: Collega la riga corrente a una nota già esistente (crea un puntatore).

    - `<leader>ad` -> Delete: Cancella la nota (o il link) sotto il cursore.

    - `<leader>al` -> List: Mostra tutte le note nel file corrente.

    - `<leader>av` -> Virtual Text: Attiva/Disattiva il testo fantasma a lato del codice.

    - `[n` / `]n` -> Navigazione: Salta alla nota precedente / successiva nel file.

3. Il "Cervello" & Task

    - `<leader>at` -> Tasks: Mostra tutti i TODO: e checkbox sparsi nelle note e nella lavagna.

    - `<leader>as` -> Search: Cerca testo globale dentro tutte le note del progetto.

    - `<leader>aD` -> Doctor: Trova e ripara le note orfane (file cancellati/spostati).

4. Dentro una Nota (Finestra Flottante)

    - `<leader>ao` -> Go Definition: Salta al file e alla riga di codice a cui la nota si riferisce.

    - `<leader>ab` -> Backlinks: Mostra chi sta puntando alla nota che stai leggendo.

    - `<leader>af` -> segui il link sotto il cursore verso la nuova nota

    - `<leader>ax` -> Inserisce un link verso un'altra nota ([[note:ID|Titolo]]).

    - `q / <Esc>` -> Chiude e salva.



