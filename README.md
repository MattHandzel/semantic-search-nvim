#### Description

This is a [Neovim](https://neovim.io/) extension to my other [project](https://github.com/MattHandzel/SemanticNoteSearch). After setting that project up, this neovim plugin will allow you to search your notes for other notes that are semantically similar!

Ensure that the server is running before using this plugin, in the future I'll try and put them all together in one, but they are separate now!

#### Commands

[![Neovim plugin demo](https://img.youtube.com/vi/EjFkBbcjG08/0.jpg)](https://youtu.be/EjFkBbcjG08)

```
:SemanticSearch
```

This command will query the server with the content of the current buffer, and return the title of the returned notes. It will open up a popup where you can press `enter` on the list to select the note titles you want to link to, and then press `q` to exit from the buffer, copying the note titles in a wiki-style format into your clipboard to link to your other notes.

#### Config

```lua
{
    threshold = 0.6, -- The threshold for the cosine similarity, the higher the number the more similar the notes need to be to be returned (I think 0.6 works well)

}

```

```

```
