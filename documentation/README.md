# 🗺️ App Luoghi Segreti - Versione 2.0

Un'app iOS moderna che mostra una mappa interattiva con i pin di luoghi segreti/sconosciuti, recuperati da un database Supabase in tempo reale.

## ✨ Funzionalità Principali

### 🗺️ **Mappa Intelligente**
- Caricamento dinamico basato sulla regione visibile
- Aggiornamento automatico quando muovi o zoomi la mappa
- Pin personalizzati con animazioni fluide
- Cerchio di ricerca visuale opzionale

### 🔍 **Ricerca Avanzata**
- Barra di ricerca integrata nella navigation bar
- Cerca per nome, città, paese o descrizione
- Risultati in tempo reale mentre digiti
- Funziona sia in vista mappa che lista

### 📋 **Vista Lista Moderna**
- Card eleganti con immagini e gradienti
- Mostra distanza dalla tua posizione
- Skeleton loading durante il caricamento
- Empty state quando non ci sono risultati

### � **Doppia Vista con Tab**
- **Tab Mappa**: esplora visualmente i luoghi
- **Tab Lista**: naviga facilmente tra i luoghi
- Sincronizzazione automatica tra le viste

### 🎨 **UI/UX Migliorata**
- Design moderno con Material Design
- Animazioni fluide e spring animations
- Gradienti e ombre per profondità
- Floating action buttons
- Loading states e feedback visivi

### 📍 **Funzioni Intelligenti**
- **Qui vicino**: trova luoghi nel raggio impostato
- **Geolocalizzazione**: trova automaticamente la tua posizione
- **Dettagli completi**: foto, descrizione, indicazioni
- **Apertura in Maps**: navigazione con Apple Maps
- **Statistiche**: mostra numero di luoghi caricati

## 🚀 Setup

### 1. Aggiungi Supabase Swift Package

**IMPORTANTE**: Prima di compilare l'app, devi aggiungere il package Supabase:

1. Apri il progetto `app ch3.xcodeproj` in Xcode
2. Vai su **File → Add Package Dependencies...**
3. Incolla questo URL: `https://github.com/supabase-community/supabase-swift`
4. Clicca su **Add Package**
5. Seleziona **Supabase** dalla lista e aggiungilo al target **app ch3**

### 2. Configura Info.plist in Xcode

Il file `Info.plist` è già stato creato con i permessi necessari, ma devi assicurarti che sia collegato al target:

1. In Xcode, seleziona il file `Info.plist` nella sidebar
2. Verifica che sia incluso nel target **app ch3**
3. Oppure aggiungi manualmente le chiavi nel target:
   - Vai su **Target → app ch3 → Info**
   - Aggiungi la chiave: `Privacy - Location When In Use Usage Description`
   - Valore: `Abbiamo bisogno della tua posizione per mostrarti i luoghi segreti vicino a te.`

### 3. Compila ed esegui

1. Seleziona un simulatore iOS (iPhone 15 Pro consigliato)
2. Premi **Cmd + R** per compilare ed eseguire
3. Quando richiesto, autorizza l'accesso alla posizione

## 📂 Struttura del progetto

```
app ch3/
├── app_ch3App.swift              # Entry point dell'app
├── SupabaseManager.swift          # Client Supabase (singleton)
├── Models/
│   └── Place.swift                # Modello dati per i luoghi
├── ViewModels/
│   └── PlacesViewModel.swift      # Logica business, fetch e ricerca
├── Managers/
│   └── LocationManager.swift      # Gestione geolocalizzazione
└── Views/
    ├── MainView.swift             # Vista principale con TabView
    ├── ImprovedMapView.swift      # Mappa con UI migliorata
    ├── PlacesListView.swift       # Lista con card moderne
    ├── PlaceDetailView.swift      # Dettagli di un luogo
    └── ImprovedSettingsView.swift # Impostazioni con statistiche
```

## 🎯 Come usare l'app

### **All'avvio**
1. L'app richiede i permessi di localizzazione
2. Carica automaticamente i luoghi nella tua zona
3. Scegli tra vista Mappa o Lista usando le tab in basso

### **Ricerca**
1. Tocca la barra di ricerca in alto
2. Digita il nome di un luogo, città o parola chiave
3. I risultati si filtrano automaticamente in entrambe le viste

### **Navigazione Mappa**
- **Muovi la mappa**: i luoghi si aggiornano automaticamente
- **Zoom in/out**: carica luoghi nell'area visibile
- **Tocca un pin**: apri i dettagli del luogo
- **Bottone cerchio** (⭕): mostra/nascondi l'area di ricerca
- **"Qui vicino"**: cerca luoghi nel raggio impostato

### **Vista Lista**
- **Scroll**: naviga tra tutti i luoghi
- **Tocca una card**: apri i dettagli
- **Vedi distanza**: quanto dista ogni luogo da te
- **Immagini**: anteprima fotografica di ogni luogo

### **Impostazioni**
- Statistiche luoghi caricati
- Regola il raggio di ricerca (5-200 km)
- Informazioni su come funziona l'app

## 🐛 Troubleshooting

### Errore "Cannot find 'SupabaseClient' in scope"
- Assicurati di aver aggiunto il package Supabase (vedi step 1)

### La mappa non mostra la posizione
- Verifica i permessi in **Impostazioni → Privacy → Localizzazione**
- Controlla che l'Info.plist contenga la chiave per i permessi

### Nessun luogo visualizzato
- Verifica la connessione internet
- Controlla che la tabella `places` su Supabase contenga dati
- Guarda i log nella console di Xcode per eventuali errori

## 📱 Requisiti

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Connessione internet

## 🎨 Personalizzazione

### Cambiare il colore dei pin
In `ImprovedMapView.swift`, modifica:
```swift
LinearGradient(
    colors: [.red, .red.opacity(0.7)],  // Cambia .red con il colore desiderato
    startPoint: .top,
    endPoint: .bottom
)
```

### Cambiare il colore delle card
In `PlacesListView.swift`, modifica i gradienti:
```swift
LinearGradient(
    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],  // Personalizza i colori
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Cambiare lo stile della mappa
In `ImprovedMapView.swift`, modifica:
```swift
.mapStyle(.standard(elevation: .realistic))
// Altre opzioni: .hybrid, .imagery, .standard(elevation: .flat)
```

### Modificare il delay di aggiornamento mappa
In `ImprovedMapView.swift`, modifica:
```swift
try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 secondi (modifica il valore)
```

## 📝 Note Tecniche

- **Caricamento intelligente**: L'app carica solo i luoghi nella regione visibile con un margine del 50%
- **Debounce**: Delay di 0.5 secondi per evitare troppe chiamate API durante lo scroll
- **Cache regione**: Evita di ricaricare la stessa regione se ti muovi poco
- **Limite query**: Massimo 500 luoghi per query (sicurezza)
- **Filtro automatico**: Nasconde luoghi con `hide_from_maps = "true"`
- **Ricerca ottimizzata**: Cerca in tempo reale su tutti i campi testuali

## 🆕 Novità Versione 2.0

✨ **Ricerca avanzata** - Trova luoghi per nome, città o descrizione  
📋 **Vista lista** - Naviga facilmente tra i luoghi con card moderne  
🎨 **UI rinnovata** - Design moderno con animazioni fluide  
⚡ **Performance** - Caricamento ottimizzato e più veloce  
📊 **Statistiche** - Vedi quanti luoghi sono disponibili  
🔄 **Loading states** - Skeleton loading e feedback visivi  
🎯 **UX migliorata** - Interazioni più intuitive e piacevoli

---

Buona esplorazione dei luoghi segreti! 🗺️✨
