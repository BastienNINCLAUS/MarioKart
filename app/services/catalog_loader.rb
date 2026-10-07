# Charge le catalogue (db/catalog/*.yml) en base ; idempotent, appelé par db/seeds.rb.
class CatalogLoader
  class Error < StandardError; end

  DEFAULT_DIR = Rails.root.join("db/catalog")

  def self.call(dir = DEFAULT_DIR)
    new(dir).call
  end

  def initialize(dir)
    @dir = Pathname(dir)
  end

  def call
    entries = Dir[@dir.join("*.yml")].sort.flat_map { |file| entries_from(file) }
    keys = entries.map { |entry| entry[:key] }
    duplicates = keys.select { |key| keys.count(key) > 1 }.uniq
    raise Error, "Clés en double dans le catalogue : #{duplicates.join(', ')}" if duplicates.any?

    CatalogItem.transaction { entries.map { |entry| upsert(entry) } }
  end

  private

  def entries_from(file)
    data = YAML.safe_load_file(file)
    raise Error, "#{File.basename(file)} : attendu un kind et une liste items" unless data.is_a?(Hash) && data["items"].is_a?(Array)

    data["items"].map { |item| item.to_h.symbolize_keys.merge(kind: data["kind"]) }
  end

  def upsert(attributes)
    item = CatalogItem.find_or_initialize_by(key: attributes[:key])
    item.update!(attributes)
    item
  rescue ActiveRecord::RecordInvalid => error
    raise Error, "#{attributes[:key]} : #{error.record.errors.full_messages.to_sentence}"
  end
end
