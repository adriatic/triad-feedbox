// Generated from the local database by `npm run db:types` (supabase gen types). Do not edit by hand.

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "board_owners": {
                  Row: {
                    "board_id": string,"created_at": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "board_id": string,"created_at"?: string,"user_id": string
                  }
                  Update: {
                    "board_id"?: string,"created_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "board_owners_board_id_fkey"
      columns: ["board_id"]
isOneToOne: false
      referencedRelation: "boards"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "board_owners_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"boards": {
                  Row: {
                    "created_at": string,"id": string,"intro": string,"name": string,"slug": string,"tagline": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"intro"?: string,"name": string,"slug": string,"tagline"?: string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"intro"?: string,"name"?: string,"slug"?: string,"tagline"?: string
                  }
                  Relationships: [
                    
                  ]
                },"changelog_entries": {
                  Row: {
                    "board_id": string,"created_at": string,"created_by": string | null,"id": string,"published_at": string | null,"released_on": string,"title": string
                  }
                  ComputedFields: never
                  Insert: {
                    "board_id": string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"published_at"?: string | null,"released_on": string,"title": string
                  }
                  Update: {
                    "board_id"?: string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"published_at"?: string | null,"released_on"?: string,"title"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "changelog_entries_board_id_fkey"
      columns: ["board_id"]
isOneToOne: false
      referencedRelation: "boards"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "changelog_entries_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"changelog_items": {
                  Row: {
                    "entry_id": string,"idea_id": number,"note": string,"position": number
                  }
                  ComputedFields: never
                  Insert: {
                    "entry_id": string,"idea_id": number,"note": string,"position"?: number
                  }
                  Update: {
                    "entry_id"?: string,"idea_id"?: number,"note"?: string,"position"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "changelog_items_entry_id_fkey"
      columns: ["entry_id"]
isOneToOne: false
      referencedRelation: "changelog_entries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "changelog_items_idea_id_fkey"
      columns: ["idea_id"]
isOneToOne: true
      referencedRelation: "ideas"
      referencedColumns: ["id"]
    }
                  ]
                },"comments": {
                  Row: {
                    "author_id": string,"body": string,"created_at": string,"hidden_at": string | null,"hidden_by": string | null,"id": number,"idea_id": number,"moved_from_idea_id": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "author_id"?: string,"body": string,"created_at"?: string,"hidden_at"?: string | null,"hidden_by"?: string | null,"id"?: never,"idea_id": number,"moved_from_idea_id"?: number | null
                  }
                  Update: {
                    "author_id"?: string,"body"?: string,"created_at"?: string,"hidden_at"?: string | null,"hidden_by"?: string | null,"id"?: never,"idea_id"?: number,"moved_from_idea_id"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "comments_author_id_fkey"
      columns: ["author_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "comments_hidden_by_fkey"
      columns: ["hidden_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "comments_idea_id_fkey"
      columns: ["idea_id"]
isOneToOne: false
      referencedRelation: "ideas"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "comments_moved_from_idea_id_fkey"
      columns: ["moved_from_idea_id"]
isOneToOne: false
      referencedRelation: "ideas"
      referencedColumns: ["id"]
    }
                  ]
                },"ideas": {
                  Row: {
                    "author_id": string,"board_id": string,"body": string,"comment_count": number,"created_at": string,"hidden_at": string | null,"hidden_by": string | null,"id": number,"merged_into_id": number | null,"shipped_at": string | null,"status": Database["public"]['Enums']["idea_status"],"status_changed_at": string,"title": string,"updated_at": string,"vote_count": number
                  }
                  ComputedFields: never
                  Insert: {
                    "author_id"?: string,"board_id": string,"body"?: string,"comment_count"?: number,"created_at"?: string,"hidden_at"?: string | null,"hidden_by"?: string | null,"id"?: never,"merged_into_id"?: number | null,"shipped_at"?: string | null,"status"?: Database["public"]['Enums']["idea_status"],"status_changed_at"?: string,"title": string,"updated_at"?: string,"vote_count"?: number
                  }
                  Update: {
                    "author_id"?: string,"board_id"?: string,"body"?: string,"comment_count"?: number,"created_at"?: string,"hidden_at"?: string | null,"hidden_by"?: string | null,"id"?: never,"merged_into_id"?: number | null,"shipped_at"?: string | null,"status"?: Database["public"]['Enums']["idea_status"],"status_changed_at"?: string,"title"?: string,"updated_at"?: string,"vote_count"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "ideas_author_id_fkey"
      columns: ["author_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ideas_board_id_fkey"
      columns: ["board_id"]
isOneToOne: false
      referencedRelation: "boards"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ideas_hidden_by_fkey"
      columns: ["hidden_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ideas_merged_into_id_fkey"
      columns: ["merged_into_id"]
isOneToOne: false
      referencedRelation: "ideas"
      referencedColumns: ["id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "created_at": string,"display_name": string | null,"id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"display_name"?: string | null,"id": string
                  }
                  Update: {
                    "created_at"?: string,"display_name"?: string | null,"id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"votes": {
                  Row: {
                    "created_at": string,"idea_id": number,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"idea_id": number,"user_id"?: string
                  }
                  Update: {
                    "created_at"?: string,"idea_id"?: number,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "votes_idea_id_fkey"
      columns: ["idea_id"]
isOneToOne: false
      referencedRelation: "ideas"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "votes_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "has_display_name":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"hide_comment":
{ Args: { "p_comment_id": number }; Returns: undefined
                           },
"hide_idea":
{ Args: { "p_idea_id": number }; Returns: undefined
                           },
"is_board_owner":
{ Args: { "p_board_id": string }; Returns: boolean
                           },
"merge_ideas":
{ Args: { "p_source_id": number,"p_target_id": number }; Returns: number
                           },
"publish_changelog_entry":
{ Args: { "p_entry_id": string,"p_publish"?: boolean }; Returns: undefined
                           },
"set_idea_status":
{ Args: { "p_idea_id": number,"p_status": Database["public"]['Enums']["idea_status"] }; Returns: undefined
                           },
"similar_ideas":
{ Args: { "p_board_id": string,"p_include_body"?: boolean,"p_limit"?: number,"p_query": string }; Returns: {
              "id": number,"score": number,"status": Database["public"]['Enums']["idea_status"],"title": string,"vote_count": number
            }[]
                           },
"unhide_comment":
{ Args: { "p_comment_id": number }; Returns: undefined
                           },
"unhide_idea":
{ Args: { "p_idea_id": number }; Returns: undefined
                           }
          }
          Enums: {
            "idea_status": "open"|"planned"|"building"|"shipped"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            "idea_status": ["open", "planned", "building", "shipped"]
          }
        }
} as const
