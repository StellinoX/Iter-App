# 📦 IMPORTANTE: Setup Supabase Package

## ⚠️ PRIMA DI ESEGUIRE L'APP

Devi aggiungere manualmente il package Supabase in Xcode:

### Passaggi:

1. **Apri il progetto in Xcode**
   - Fai doppio click su `app ch3.xcodeproj`

2. **Aggiungi il Package**
   - Menu: **File → Add Package Dependencies...**
   - Nella barra di ricerca, incolla: 
     ```
     https://github.com/supabase-community/supabase-swift
     ```
   - Premi invio e aspetta che carichi

3. **Seleziona il package**
   - Nella lista che appare, seleziona **Supabase**
   - Clicca **Add Package** in basso a destra

4. **Aggiungi al target**
   - Nella finestra che si apre, assicurati che **Supabase** sia selezionato
   - Seleziona il target **app ch3**
   - Clicca **Add Package**

5. **Verifica**
   - Vai su **Project Navigator** (icona cartella in alto a sinistra)
   - Espandi **Package Dependencies**
   - Dovresti vedere **supabase-swift**

### Ora puoi compilare l'app! 🚀

Premi **Cmd + R** per eseguire l'app.
