//
//  CategoryGroup.swift
//  app ch3
//
//  Macro-categories that group detailed categories into simpler filters
//  Based on 587 unique tags from Supabase database
//

import Foundation
import SwiftUI

// MARK: - Macro Category Groups

enum CategoryGroup: String, CaseIterable, Identifiable, Hashable {
    case abandoned = "Abandoned & Urbex"
    case nature = "Nature"
    case history = "History"
    case artMuseums = "Art & Museums"
    case sacred = "Sacred & Religious"
    case science = "Science & Oddities"
    case architecture = "Architecture"
    case darkTourism = "Dark Tourism"
    case food = "Food & Drink"
    case quirky = "Quirky & Unusual"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .abandoned: return "building.2.crop.circle"
        case .nature: return "leaf.fill"
        case .history: return "building.columns.fill"
        case .artMuseums: return "paintpalette.fill"
        case .sacred: return "cross.fill"
        case .science: return "atom"
        case .architecture: return "building.fill"
        case .darkTourism: return "moon.stars.fill"
        case .food: return "fork.knife"
        case .quirky: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .abandoned: return .orange
        case .nature: return .green
        case .history: return .brown
        case .artMuseums: return .purple
        case .sacred: return .blue
        case .science: return .cyan
        case .architecture: return .indigo
        case .darkTourism: return .gray
        case .food: return .red
        case .quirky: return .pink
        }
    }
    
    /// Keywords that belong to this macro-category (based on real database tags)
    var keywords: [String] {
        switch self {
        case .abandoned:
            return [
                "Abandoned", "Abandoned Hospitals", "Abandoned Insane Asylums", "Abandoned Mines",
                "Bunkers", "Ghost Towns", "Ruins", "Underground", "Subterranean", "Subterranean Sites",
                "Tunnels", "Mines", "Mining", "Quarries", "Cold War", "Nuclear", "Radioactive",
                "Decay", "Derelict", "Exploration", "Secret", "Secret Passages", "Urbex",
                "Subways", "Sewers", "Infrastructure", "Industrial", "Landfills", "Object Cemeteries",
                "Ship Graveyards", "Shipwrecks"
            ]
        case .nature:
            return [
                "Nature", "Natural Wonders", "Natural History", "Beaches", "Caves", "Cliffs",
                "Deserts", "Ecosystems", "Geological Oddities", "Geology", "Geysers", "Glaciers",
                "Islands", "Animal Islands", "Lakes", "Mountains", "Volcanoes", "Water",
                "Hot Springs", "Travertine Terraces", "Blue Holes", "Reefs", "Oceans",
                "Plants", "Trees", "Flowers", "Flora", "Gardens", "Orchards", "Horticulture",
                "Botanical", "Carnivorous Plants", "Fungus", "Bioluminescence",
                "Animals", "Birds", "Bats", "Cats", "Dogs", "Goats", "Horses", "Monkeys",
                "Rats", "Snakes", "Sharks", "Whales", "Elephants", "Insects", "Reptiles",
                "Endangered Animals", "Extinct Animals", "Wildlife", "Zoos",
                "Craters", "Earthquakes", "Floods", "Weather", "Weird Weather Phenomena",
                "Lightning", "Rainbow", "Singing Sands", "Wonders Of Salt", "Salt",
                "Rocks", "Mushroom Rocks", "Crystals", "Minerals", "Stone", "Stonehenge"
            ]
        case .history:
            return [
                "History", "History & Culture", "Archaeology", "Ancient", "Ancient Cults",
                "Prehistoric", "Megalithic", "Geoglyphs", "Petroglyphs", "Mayan", "Mesoamerica",
                "Roman", "Egyptian", "Egyptian Collections", "Pyramids",
                "Castles", "Modern Castles", "Forts", "Fortresses", "Sea Forts", "Walls",
                "Civil War", "American Revolution", "War History", "War Memorial", "Military",
                "Military History", "World War II", "WWII", "WWI", "Battlefields",
                "Colonialism", "Communism", "Soviet History", "Soviet Architecture",
                "Holocaust", "Slavery", "Black History", "Indigenous", "Native Americans",
                "Gold Rush", "Old West", "Wild West", "Railroads", "Trains", "Transportation",
                "Canals", "Boats", "Ships", "Titanic", "RMS Titanic",
                "Abraham Lincoln", "Al Capone", "Alan Turing", "Albert Einstein", "Charles Dickens",
                "Edgar Allan Poe", "Emperor Norton", "Galileo", "Jack London", "Mark Twain",
                "Nicola Tesla", "Shakespeare", "Dead Explorers", "Nobel Prize", "Royalty"
            ]
        case .artMuseums:
            return [
                "Art", "Art Museum", "Art Libraries", "Art Nouveau", "Art Outside",
                "Museums", "Museums And Collections", "Collections", "Niche Museums",
                "Gallery", "Galleries", "Sculptures", "Sculpture Gardens", "Paintings",
                "Wonder Cabinets", "Wunderkammers", "Outsider Art", "Naive Art",
                "Dioramas", "Models", "Miniatures", "Miniature Towns", "Small Worlds And Model Towns",
                "Street Art", "Murals", "Bottle Art", "Hair Art", "Microminiature Art", "Desert Art",
                "Earthworks", "Topiary", "Arbortecture", "Gnomes", "Statues", "Giant Heads",
                "Monuments", "Memorial", "Plaques", "Signs",
                "Animation", "Film", "Film Locations", "Cinema", "Disney", "Star Wars", "Godzilla",
                "Music", "Musical Roads", "Mechanical Instruments", "Organs", "Sea Organ",
                "Puppets", "Dolls", "Amazing Automata", "Automata", "Robots",
                "Literature", "Poetry", "Books", "Bookstores", "Libraries", "Rare Books",
                "Typography", "Invented Languages", "Esperanto"
            ]
        case .sacred:
            return [
                "Sacred Spaces", "Sacred", "Churches", "Cathedrals", "Basilicas", "Chapels",
                "Temples", "Monasteries", "Abbeys", "Convents", "Pagodas", "Shrines",
                "Buddhism", "Buddha", "Hinduism", "Christianity", "Islam", "Judaism",
                "Catacombs", "Catacombs And Crypts", "Crypts", "Columbariums",
                "Burial Places", "Tombs", "Mausoleums", "Graves", "Gravestones", "Graveyards",
                "Relics", "Relics And Reliquaries", "Saints", "Miracles", "Pilgrimage", "Pilgrimages",
                "Rites And Rituals", "Rituals", "Religion", "Spiritual",
                "Capuchins", "Freemasons", "Occult", "Alchemy", "Black Magic", "Witchcraft", "Voodoo"
            ]
        case .science:
            return [
                "Science", "Science Museums", "Strange Science", "Instruments Of Science",
                "Astronomy", "Observatories", "Telescopes", "Orreries", "Solar System Models",
                "Sundials", "Astounding Timepieces", "Astronomical Clocks", "Clocks", "Time",
                "Electrical Oddities", "Electricity", "Tesla Coil", "Neutrino Detectors",
                "Laboratories", "Computers", "Seti", "Nasa", "Space Exploration", "Mars",
                "Medical Museums", "Anatomy", "Anatomy Museums", "Anatomical Theaters",
                "Anatomical Venuses", "Wax Anatomy", "Blaschka Models", "Moulage",
                "Pharmacy Museums", "Apothecaries", "Medicine", "Surgery", "Genetics",
                "Dental Museums", "Mental Health", "Psychiatry", "Insane Asylums",
                "Optical Oddities", "Optical Illusions", "Cameras Obscura",
                "Physics", "Mathematics", "Atom Bombs", "Inventions", "Retro Tech",
                "Engineering", "Solar Power", "Wind Tunnels", "Pneumatic Tubes"
            ]
        case .architecture:
            return [
                "Architecture", "Architectural Oddities", "Brutalism", "Baroque", "Renaissance",
                "Art Nouveau", "Frank Lloyd Wright", "Buckminster Fuller",
                "Domes", "Towers", "Skyscrapers", "Belltowers", "Lighthouses",
                "Bridges", "Stairs", "Silos", "Water Towers", "Windmills", "Stepwells",
                "Eccentric Homes", "Homes", "Houses", "Mansions", "Treehouses", "Bottle Houses",
                "Follies And Grottoes", "Grottoes", "Mazes", "Hedge Mazes",
                "Places To Stay", "Hotels", "Castles", "Palaces",
                "Glass Conservatories", "Greenhouses", "Botanical Tunnels",
                "Dovecotes", "Spite House", "Modern", "Contemporary",
                "Fountains", "Peculiar Fountains", "Water Temples"
            ]
        case .darkTourism:
            return [
                "Death", "Memento Mori", "Skulls", "Skeletons", "Bones", "Severed Heads", "Severed Limbs",
                "Mummies", "Self Mummified", "Ossuaries", "Cemeteries", "Funeral Art", "Funeral Cars",
                "Prisons", "Crime", "Crime Museums", "Crime And Punishment", "Murder", "Serial Killer",
                "Body Snatching", "Burke & Hare", "Brothels", "Suicide", "Animal Suicide",
                "Taxidermy", "Hunting And Taxidermy", "Heroes Of Taxidermy", "Two Headed Animals",
                "Feejee Mermaids", "Anthropomorphic",
                "Haunted", "Ghosts", "Paranormal", "Witches", "Vampires", "Horror",
                "Disaster Areas", "Disasters", "Fires", "Earthquakes", "Floods", "Pollution",
                "Leprosy", "Quarantine", "Hospitals", "Hygiene"
            ]
        case .food:
            return [
                "Food", "Food Museums", "Food Disasters", "Restaurants", "Unique Restaurants & Bars",
                "Bars", "Pubs", "Cocktails", "Alcohol", "Breweries", "Distilleries", "Wine", "Wineries",
                "Markets", "Night Markets", "Shops", "Stores", "Shopping", "Antiques",
                "Coffee", "Tea", "Teahouse", "Chocolate", "Bananas", "Hot Dogs", "Donuts", "Taco",
                "Lunch", "Dining", "Gastronomy", "Street Food",
                "Purveyors Of Curiosities"
            ]
        case .quirky:
            return [
                "Roadside Attractions", "World's Largest", "World's Smallest", "World's Oldest",
                "World's Tallest", "World Record", "Giant", "Giant Spheres", "Big Chairs",
                "Oddities", "Quirky", "Weird", "Strange", "Unusual", "Unique", "Mystery",
                "Mystery Spots And Gravity Hills", "Gravity Hill",
                "Cryptozoology", "Monsters", "Aliens", "Ufos", "Dragons", "Mermaids",
                "Hoaxes", "Hoaxes And Pseudoscience", "Conspiracy Theories",
                "Dime Store Museum", "Wondrous Performances", "Circus", "Amusement Parks",
                "Arcades", "Pinball", "Gambling", "Miniature Golf", "Golf",
                "Neon", "Advertising", "Pop Culture", "Television", "Wrestling",
                "Burning Man", "Festivals", "Weddings", "Tourism",
                "Seen From Space", "Recursive Places", "Geographic Oddities", "Geographic Markers",
                "Borders", "Micro Nations", "Territorial Dispute", "Utopias",
                "Time Travel", "Time Capsule", "Long Now Locations",
                "Gum", "Shoes", "Noses", "Hands", "Hearts", "Thrones", "Bathrooms",
                "Smells", "Sounds", "Whispering Gallery", "Color"
            ]
        }
    }
    
    /// Check if a tags_title string matches this macro-category
    func matches(_ tagsTitle: String) -> Bool {
        let lowercased = tagsTitle.lowercased()
        return keywords.contains { keyword in
            lowercased.contains(keyword.lowercased())
        }
    }
    
    /// Get all matching macro-categories for a given tags_title
    static func groupsFor(_ tagsTitle: String) -> [CategoryGroup] {
        var matches: [CategoryGroup] = []
        for group in CategoryGroup.allCases {
            if group.matches(tagsTitle) {
                matches.append(group)
            }
        }
        // If no matches, return quirky as fallback (catches everything unusual)
        return matches.isEmpty ? [.quirky] : matches
    }
    
    /// Check if any of the selected groups match a tags_title
    static func anyMatch(groups: Set<CategoryGroup>, tagsTitle: String?) -> Bool {
        guard let tags = tagsTitle, !tags.isEmpty else { return true } // Show places without tags
        if groups.isEmpty { return true } // No filter = show all
        
        return groups.contains { group in
            group.matches(tags)
        }
    }
}
