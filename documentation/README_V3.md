# 🗺️ App Luoghi Segreti - Versione 3.0

Un'app iOS moderna che mostra una mappa interattiva con i pin di luoghi segreti/sconosciuti, recuperati da un database Supabase in tempo reale. Ora con sistema di preferiti, tracciamento luoghi visitati e filtri per categorie!

## ✨ Novità Versione 3.0

### ❤️ **Sistema Preferiti**
- Nuova tab "Preferiti" per accedere rapidamente ai tuoi luoghi salvati
- Pulsante cuore nei dettagli per aggiungere/rimuovere preferiti
- Persistenza automatica con UserDefaults
- Badge visivo sulla tab con numero di preferiti

### ✅ **Luoghi Visitati**
- Segna i luoghi come visitati con un tap
- I pin sulla mappa cambiano colore: **giallo-verde (#BFF207)** per non visitati, **viola (#7F6EF1)** per visitati
- Stato persistente tra le sessioni
- Feedback visivo immediato

### 🏷️ **Filtri per Categorie**
- Filtra luoghi per `tags_title` nelle impostazioni
- Seleziona/deseleziona categorie con toggle
- Filtri applicati a Mappa, Lista e Ricerca
- Pulsante per rimuovere tutti i filtri
- Contatore luoghi filtrati

### 🎨 **Nuova Palette Colori**
- Background: **#1F092F** (viola scuro)
- Accento/Importante: **#BFF207** (giallo-verde)
- Luoghi visitati: **#7F6EF1** (viola chiaro)
- Tema coerente su tutta l'app

## 📱 Funzionalità Principali

### 🗺️ **Mappa Intelligente**
- Caricamento dinamico basato sulla regione visibile
- Aggiornamento automatico quando muovi o zoomi la mappa
- Pin personalizzati con animazioni fluide e colori dinamici
- Cerchio di ricerca visuale opzionale (giallo-verde)

### 🔍 **Ricerca Avanzata**
- Barra di ricerca integrata nella navigation bar
- Cerca per nome, città, paese o descrizione
- Risultati in tempo reale mentre digiti
- Funziona con filtri categorie attivi

### 📋 **Vista Lista Moderna**
- Card eleganti con immagini e gradienti
- Mostra distanza dalla tua posizione
- Skeleton loading durante il caricamento
- Empty state quando non ci sono risultati
- Background viola scuro

### 📍 **Funzioni Intelligenti**
- **Qui vicino**: trova luoghi nel raggio impostato
- **Geolocalizzazione**: trova automaticamente la tua posizione
- **Dettagli completi**: foto, descrizione, indicazioni
- **Apertura in Maps**: navigazione con Apple Maps
- **Statistiche**: numero luoghi caricati, visibili, preferiti

## 🎯 Come usare l'app

### **Tab Mappa**
- Visualizza pin sulla mappa (giallo-verde = non visitati, viola = visitati)
- Tocca un pin per aprire i dettagli
- Usa il pulsante cerchio per mostrare l'area di ricerca
- Pulsante "Qui vicino" per cercare nella tua zona

### **Tab Lista**
- Scorri le card dei luoghi
- Vedi distanza e anteprima foto
- Tocca per aprire i dettagli

### **Tab Preferiti ❤️**
- Accedi rapidamente ai tuoi luoghi salvati
- Stessa interfaccia della lista
- Sincronizzato in tempo reale con i preferiti

### **Dettagli Luogo**
- **Cuore** (in alto a sinistra): aggiungi/rimuovi dai preferiti
- **Segna come visitato**: cambia stato e colore pin
- **Apri in Mappe**: navigazione diretta
- **Chiudi**: torna alla vista precedente

### **Impostazioni ⚙️**
- **Statistiche**: vedi contatori luoghi
- **Filtri categorie**: seleziona quali categorie visualizzare
- **Raggio ricerca**: 5-200 km per "Qui vicino"
- **Info**: come funziona l'app

## 📂 Struttura del progetto

```
app ch3/
├── app_ch3App.swift              # Entry point
├── SupabaseManager.swift          # Client Supabase
├── Extensions/
│   └── Color+Extensions.swift     # Colori personalizzati (#BFF207, #1F092F, #7F6EF1)
├── Models/
│   └── Place.swift                # Modello dati luoghi
├── ViewModels/
│   └── PlacesViewModel.swift      # Logica: fetch, filtri, preferiti, visitati
├── Managers/
│   ├── LocationManager.swift      # Geolocalizzazione
│   └── UserDefaultsManager.swift  # Persistenza (preferiti, visitati, filtri)
└── Views/
    ├── MainView.swift             # TabView principale (3 tab)
    ├── ImprovedMapView.swift      # Mappa con pin colorati dinamicamente
    ├── PlacesListView.swift       # Lista luoghi
    ├── FavoritesView.swift        # Lista preferiti
    ├── PlaceDetailView.swift      # Dettagli + cuore + visitato
    └── ImprovedSettingsView.swift # Settings + filtri categorie
```

## 🔧 Persistenza Dati

L'app salva automaticamente:
- **Preferiti**: `favoritePlaceIDs` (Set<Int64>)
- **Visitati**: `visitedPlaceIDs` (Set<Int64>)
- **Filtri categorie**: `selectedCategories` (Set<String>)

Tutti i dati persistono tra le sessioni tramite `UserDefaults`.

## 🎨 Personalizzazione

### Cambiare i colori principali
In `Color+Extensions.swift`:
```swift
static let appAccent = Color(hex: "BFF207")        // Giallo-verde
static let appBackground = Color(hex: "1F092F")    // Viola scuro
static let appVisited = Color(hex: "7F6EF1")       // Viola chiaro
```

### Modificare il raggio di ricerca default
In `ImprovedMapView.swift`:
```swift
@State private var searchRadius: Double = 50  // Cambia il valore (km)
```

## 🚀 Setup

### 1. Aggiungi Supabase Package
1. Apri il progetto in Xcode
2. File → Add Package Dependencies
3. URL: `https://github.com/supabase-community/supabase-swift`
4. Aggiungi al target **app ch3**

### 2. Compila ed esegui
- Seleziona un simulatore iOS
- Premi **Cmd + R**
- Autorizza la localizzazione quando richiesto

## 📊 Database Supabase

### Tabella `places`
```sql
- id (int8) PRIMARY KEY
- title (text)
- subtitle (text)
- city (text)
- country (text)
- coordinates_lat (float8)
- coordinates_lng (float8)
- description (text)
- directions (text)
- thumbnail_url (text)
- image_cover (text)
- tags_title (text) ← USATO PER FILTRI
- hide_from_maps (text)
```

## 📝 Note Tecniche

- **Caricamento intelligente**: Solo luoghi nella regione visibile + 50% buffer
- **Debounce**: 0.5s per ridurre chiamate API durante scroll
- **Limite query**: Max 500 luoghi per sicurezza
- **Colori dinamici**: Pin cambiano colore in base allo stato visitato
- **Filtri combinati**: Categorie + ricerca testo + regione
- **Performance**: Tutti i set (preferiti, visitati) usano Int64 per lookup O(1)

## 🆕 Changelog

### v3.0 (Dicembre 2025)
- ✨ Aggiunta tab Preferiti
- ✨ Sistema luoghi visitati con cambio colore pin
- ✨ Filtri per categorie (tags_title)
- ✨ Nuova palette colori (#BFF207, #1F092F, #7F6EF1)
- ✨ Pulsante cuore in PlaceDetailView
- ✨ Bottone "Posto visitato" (sostituisce "Scopri di più")
- ✨ Persistenza completa con UserDefaults
- 🎨 UI aggiornata con tema coerente
- 🔧 Ottimizzazioni performance filtri

### v2.0
- Ricerca avanzata
- Vista lista con card moderne
- UI/UX migliorata
- Skeleton loading

### v1.0
- Release iniziale
- Mappa con pin
- Caricamento dinamico

---

🗺️ **Scopri luoghi segreti attorno a te!** ✨
