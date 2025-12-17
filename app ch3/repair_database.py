import requests
import json
import time

# Configuration
SUPABASE_URL = "https://saexkuvejazyffwtpiih.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhZXhrdXZlamF6eWZmd3RwaWloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NTg2MTAsImV4cCI6MjA4MDIzNDYxMH0.DrVUnVN3Mg1F-wADgNlt0Kz3C7745W61Hbjq1Ll9GW4"
GEMINI_KEY = "AIzaSyCV59q-dDxnw-150KaJpTI2pPIlSUMiVAM"

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

# Dictionary patches
MANUAL_FIXES = {
    "Gro?njan": "Grožnjan",
    "V?rsar": "Vrsar",
    "Pore?": "Poreč",
    "Rovin?": "Rovinj",
    "Motov?n": "Motovun",
    "Ã¨": "è", "Ã©": "é", "â€™": "’", "Ã ": "à", "Ã¹": "ù", "Ã¬": "ì", "Ã²": "ò",
    "Caf?": "Café", "Fa?ade": "Façade", "Entr?e": "Entrée", "Pi?a": "Piña"
}

def ask_gemini_to_fix(text):
    """Uses Gemini to intelligently repair corrupted text."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_KEY}"
    
    prompt = f"""
    You are a text repair engine. The following text contains '?' or mojibake encoding errors instead of specific characters (like accents or specific letters for city names).
    Repaired it. ONLY return the repaired text. Do not add any explanation. 
    If you are not sure or if the '?' is a real question mark, return input exactly as is.
    
    Input: "{text}"
    """
    
    payload = {
        "contents": [{
            "parts": [{"text": prompt}]
        }]
    }
    
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            result = response.json()
            if 'candidates' in result and result['candidates']:
                fixed = result['candidates'][0]['content']['parts'][0]['text'].strip()
                # Safety check: don't accept if it returned something radically different in length
                if abs(len(fixed) - len(text)) > 5: 
                    return text
                return fixed.replace('"', '') # remove quotes if Gemini added them
    except Exception as e:
        print(f"Gemini Error: {e}")
        
    return text

def sanitize_text(text):
    if not text: return text
    
    # 1. Manual Dictionary
    for broken, fixed in MANUAL_FIXES.items():
        if broken in text:
            text = text.replace(broken, fixed)
            
    # 2. Heuristic check: does it still contain '?' or likely mojibake?
    if "?" in text or "Ã" in text:
        # Use AI for hard cases, but rate limit slightly
        # We only call AI if we are "pretty sure" it's broken to save time/quota
        # For now, let's trust the dictionary for speed, but if we want "more fixes" as requested:
        print(f"   ...Querying AI for: {text[:30]}...")
        text = ask_gemini_to_fix(text)
        time.sleep(1) # rate limit prevention
    
    return text

def fetch_places(offset=0, limit=1000):
    url = f"{SUPABASE_URL}/rest/v1/places?select=id,title,description&offset={offset}&limit={limit}"
    response = requests.get(url, headers=HEADERS)
    if response.status_code != 200:
        print(f"Error fetching places: {response.text}")
        return []
    return response.json()

def update_place(place_id, title=None, description=None):
    url = f"{SUPABASE_URL}/rest/v1/places?id=eq.{place_id}"
    payload = {}
    if title: payload["title"] = title
    if description: payload["description"] = description
        
    if not payload: return False
    response = requests.patch(url, headers=HEADERS, json=payload)
    return response.status_code in [200, 204]

def main():
    print("Starting AI-POWERED Database Repair Tool...")
    offset = 0
    batch_size = 1000 
    total_fixed = 0
    total_scanned = 0
    
    while True:
        print(f"Scanning batch {offset}...")
        places = fetch_places(offset, batch_size)
        if not places: break
            
        for place in places:
            total_scanned += 1
            pid, title, desc = place.get('id'), place.get('title'), place.get('description')
            
            new_title = sanitize_text(title)
            # new_desc = sanitize_text(desc) # Skip description AI for speed unless necessary
            
            needs_update = False
            
            if title and title != new_title:
                print(f"[FIX] ID {pid} Title: '{title}' -> '{new_title}'")
                if update_place(pid, title=new_title):
                    print(" -> Saved")
                    total_fixed += 1
                else:
                    print(" -> Failed")
                    
        if len(places) < batch_size: break
        offset += batch_size

    print(f"\nCompleted. Scanned: {total_scanned}, Fixed: {total_fixed}")

if __name__ == "__main__":
    main()
