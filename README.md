# Yotta64 NVIM Config 

I uploaded this config because while researching for new nvim plugins, i started writing one of my own, and from that i ended up making chatGPT write one for me.
Right now it's a just a  test, but i think it's coming out pretty cool, if i see some interest online i might learn lua properly and mantain the plugin myself (yeah chatGPT is cool but not perfect).

## 👻Ghost Nvim

right now, there are two main additions: *GhostNotes* and *GhostVault*. They share functions and paths; but i might keep them separated in the future.
i'll list the features of each one:
### GhostNotes
this plugin creates post-it like notes inside the file. It's a more advanced and complete way of commenting your code. Inside notes you can write in markdown (in my config i'm using markview to make it render better, in my opinion it doesn't really make sense without it) and add tasks. each note is saved as a file in a cache folder initiated by `GhostVault`, i'll get to that later. Each note's file saves the anchot it is attached to (file, line) and an ID, used to create links and navigate through notes. For most of the functions i'm using telescope to render the result; i'm planning to make it optional, at the moment i've added fallbacks for just a few functions. Right now it features:
- *add / edit note*: on the cursor's position attach a new note, or if there already one, open it. This opens a floating window with the note's file. Inside, you can:
    - *create a link to another note*: opens a telescope window where you can search the note you want to link
    - by hovering on a link, you can *follow that link* with a keybinding (in my config is <leader>af)
    - *show note backlink*: telescope menu with all the note that link to the current one, select one to move there
    - *go the to anchor of that note*: useful if you are moving through links and you want to go to the corresponding file
    -  press `q` to save and close
- list notes in current file: opens a telescope menu where yu can choose the note and open it
- link existing note: inside your code, you can create a link (or "reference") a note anchored somwhere else; this creates a note with type link that when opened, directly moves to the final note. Removing the link does not affect the linked notes 
- *delete note under cursor*
- note grep: search text in notes
- 
- toggle note virtual text preview
- fix note's dead link and orphan notes: a little wizard that asks you what to do with broken notes
- show tasks: This is a really work in progress feature. Right now it searches for `TODO:` inside notes; if it finds any, looks for a name, like `TODO: login` and stores it. If under the todo there is a checklist, saves each entry as a task with the `TODO:`'s name, in this case `login`, otherwise it saves the name as a task. For example:
    - `TODO: write call to API` -> saves the task `write call to API`
    
    - ```markdown 
        TODO: 
      - [ ] change font
      - [ ] make text larger
      - [x] write config
      ```

    This will save 3 different tasks with their status, `change font`:`unchecked`; `make text larger`:`unchecked`; `write configs`:`checked`. Depending on the status they will have a red or green icon in the tasks list 
    - ```markdown
        TODO: UI 
      - [ ] change font
      - [ ] make text larger
      - [x] write config
      ```
    
    This will saves each task with the group `UI`

### GhostVault
GhostVault is a project-management plugin. It creates a project, adds a "vault", the `.ghost` folder, wher it saves the state and data of the project.
- `:GhostInit` : on a new project, it asks how to you want to save the data; if you want to use git and how.
- `:GhostDelete` : deletes a project from the list
- `:GhostSwitch` : move to a project from the list; it reloads neovim with the new configuration
- `:GhostRun` : inthe vault, you can define a file called `local.lua`, loaded from with the project, with custom neovim properties. You can also define a var called `ghost_run_cmd` to createa command to execute with `:GhostRun`
- `:GhostNote`: opens a note called "scratchpad", always accessible from anywhere. It's the same as GhostNote, just common to all th files in the project
- `:GhostGit` : opens a menu with git actions assotiated with the project. Right now it features:
    - *add/remove from stage*: select files from a telescope menu
    - *commit*: opens a buffer where you can write your commit changes, and it automatically adds all the new and the modified tasks from GhostNotes
    - *open lazygit*
    - *switch branch*
    - *git pull*
    - *git push*
