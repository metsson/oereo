class Api::V1::ResourcesController < Api::ApiController

  # set pagination headers
  after_filter only: [:index] { paginate(:resources) }

  before_filter :unauthorized_unless_owner!, only: [:update, :destroy]

  def index

    filter_results

    @resources = @resources.page(params[:page]).per(params[:per_page])
    respond_with @resources, meta: pagination_meta
  end

  def show
    respond_with Resource.find(params[:id])
  end

  def create
    @resource = Resource.create(resource_params)
    apply_tags # TODO: optimize, don't save until tags are in?s

    # FIXME: Should :api really be needed? This took way to long to figure out
    respond_with :api, @resource
  end

  def update
    @resource = Resource.update(params[:id], resource_params)
    @resource.tags.clear # TODO: Updating tags can be done more efficiently
    apply_tags
    respond_with :api, @resource
  end

  def destroy
    respond_with Resource.destroy(params[:id])
  end

private

  # TODO: refactor to a method-object
  def filter_results
    # TODO: This is lazy in Rails 4 right.. right?
    @resources = Resource.all

    filter_by_tags
    filter_by_license
    filter_by_search
    filter_by_username
    filter_by_category
  end

  def filter_by_username
    @resources = @resources.joins(:user).where!('username = ?', params[:username]) unless params[:username].nil?
  end

  def filter_by_tags
    @resources.where!("tags && (ARRAY[?]::varchar[])", params[:tags].split(',')) unless params[:tags].nil?
  end

  def filter_by_search
    # ILIKE is a case insensitive search,
    # the param is wrapped in % to indicate it can be placed anywhere in the string
    @resources.where!("title ILIKE ?", "%#{params[:search]}%")
  end

  def filter_by_license
    @resources.where!(license_id: params[:license_id]) unless params[:license_id].nil?
  end

  def filter_by_category
    @resources.where!(resource_category_id: params[:category_id]) unless params[:category_id].nil?
  end


  def pagination_meta
    # TODO: Maybe just send the navigation links here as well, the header is hard to work with
    {
      total: @resources.total_count,
      page: @resources.current_page,
      count: @resources.count,
      num_pages: @resources.num_pages,
    }
  end

  def unauthorized_unless_owner!
    head :forbidden unless Resource.find(params[:id]).user == @user
  end

  def apply_tags
    @resource.tags = params[:tags].map! { |tag| tag.downcase } unless params[:tags].nil?
    @resource.save!
  end

  def resource_params
    {
      title: params[:title],
      description: params[:description],
      url: params[:url],
      user: @user, # set in api_controller
      license: License.find_by(id: params[:license_id]),
      resource_category: ResourceCategory.find_by(id: params[:resource_category_id])
    }
  end

end
