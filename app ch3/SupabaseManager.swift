//
//  SupabaseManager.swift
//  app ch3
//
//  Singleton per gestire il client Supabase
//

import Supabase
import Foundation

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        let url = URL(string: Secrets.supabaseUrl)!
        let key = Secrets.supabaseKey

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}
