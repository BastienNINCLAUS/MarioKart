module CatalogHelper
  def load_catalog
    CatalogLoader.call
  end
end
