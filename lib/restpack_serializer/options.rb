module RestPack::Serializer
  class Options
    attr_accessor :page, :page_size, :include, :filters, :serializer,
                  :model_class, :scope, :context, :include_links,
                  :sorting, :custom_order

    def initialize(serializer, params = {}, scope = nil, context = {})
      params.symbolize_keys! if params.respond_to?(:symbolize_keys!)

      @page = params[:page] ? params[:page].to_i : 1
      @page_size = params[:page_size] ? params[:page_size].to_i : RestPack::Serializer.config.page_size
      @include = params[:include] ? params[:include].split(',').map(&:to_sym) : []

      if serializer.respond_to? :filters_from_params
        @filters = serializer.filters_from_params(params, serializer)
      end

      unless @filters
        @filters = filters_from_params(params, serializer)
      end

      @sorting = sorting_from_params(params, serializer)
      @serializer = serializer
      @model_class = serializer.model_class
      @scope = scope || model_class.send(:all)
      @context = context
      @include_links = true
      @custom_order = reorder_data(params)
    end

    def scope_with_filters
      result = nil
      if @serializer.respond_to? :scope_with_filters
        result = @serializer.scope_with_filters(self)
      end

      if result
        return result
      else
        scope_filter = {}

        @filters.keys.each do |filter|
          value = query_to_array(@filters[filter])
          scope_filter[filter] = value
        end

        @scope.where(scope_filter)
      end
    end

    def custom_reorder
      result = nil
      if @serializer.respond_to? :custom_reorder
        result = @serializer.custom_reorder(self)
      end

      if result
        return result
      else
        return scope.to_a
      end
    end

    def default_page_size?
      @page_size == RestPack::Serializer.config.page_size
    end

    def filters_as_url_params
      @filters.sort.map { |k,v| map_filter_ids(k,v) }.join('&')
    end

    def sorting_as_url_params
      sorting_values = sorting.map { |k, v| v == :asc ? k : "-#{k}" }.join(',')
      "sort=#{sorting_values}"
    end

    private

    def reorder_data params
      ['true', '1', 'TRUE', 't'].include?(params["custom_order"]) ? true : false
    end

    def filters_from_params(params, serializer)
      filters = {}
      serializer.filterable_by.each do |filter|
        [filter, "#{filter}s".to_sym].each do |key|
          filters[filter] = params[key].to_s.split(',') if params[key]
        end
      end
      filters
    end

    def sorting_from_params(params, serializer)
      sort_values = params[:sort] && params[:sort].split(',')
      return {} if sort_values.blank? || serializer.serializable_sorting_attributes.blank?
      sorting_parameters = {}

      sort_values.each do |sort_value|
        sort_order = sort_value[0] == '-' ? :desc : :asc
        sort_value = sort_value.gsub(/\A\-/, '').downcase.to_sym
        sorting_parameters[sort_value] = sort_order if serializer.serializable_sorting_attributes.include?(sort_value)
      end
      sorting_parameters
    end

    def map_filter_ids(key,value)
      case value
        when Hash
          value.map { |k,v| map_filter_ids(k,v) }
        when Range
        else
          "#{key}=#{value.join(',')}"
      end
    end

    def query_to_array(value)
      case value
        when String
          value.split(',')
        when Hash
          value.each { |k, v| value[k] = query_to_array(v) }
        else
          value
      end
    end
  end
end
