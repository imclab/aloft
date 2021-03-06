class StationsScreen < PM::TableScreen
  title "Weather Stations"
  refreshable
  searchable

  def on_refresh ; refresh ; end
  def on_appear ; refresh ; end

  def on_load
    rmq.stylesheet = StationsStylesheet
    view.rmq.apply_style :root_view

    @stations = []
    unless App::Persistence['station'].nil?
      set_nav_bar_button(
        :right,
        title: 'Close',
        system_item: :stop,
        action: :close
      )
    end
  end

  def table_data
    [{
      title: "Select weather station near you:",
      cells: @stations
    }]
  end

  def refresh
    ap "refreshing" if BW.debug?
    Flurry.logEvent("REFRESH_STATIONS") unless Device.simulator?

    return alert_location_services_off unless BW::Location.enabled?

    BW::Location.get_once do |location|
      if location.is_a?(CLLocation)
        ap "got location." if BW.debug?
        find_stations(location)
      else
        alert_location_services_off
      end
    end
  end

  def alert_location_services_off
    end_refreshing
    Flurry.logEvent("LOCATION_SERVICES_OFF") unless Device.simulator?
    App.alert("Location Services\nAre Disabled", {
      message: "Please enable location services for #{App.name} in the settings app and try again."
    })
  end

  def find_stations(location)
    ap "Finding stations" if BW.debug?

    Stations.client.sorted_by_distance_from(location) do |s|
      end_refreshing

      if s.is_a?(NSError)
        Flurry.logEvent("STATIONS_API_ERROR") unless Device.simulator?
        ap "Got an error from the stations API" if BW.debug?

        App.alert("Error retrieving stations", {
          message: "There was an error retrieving the list of weather stations.\n\nPlease try again or email mark@mohawkapps.com\nfor support."
        })
      else
        map_and_show_stations(s)
      end
    end
  end

  def map_and_show_stations(data)
    @stations = data.map do |station|
      {
        title: station[:name],
        subtitle: subtitle(station),
        search_text: "#{station[:name]} #{station[:code]}",
        action: :select_station,
        height: 60,
        arguments: { station: station }
      }
    end
    update_table_data
  end

  def subtitle(station)
    if App::Persistence['metric'] == true
      distance = station[:current_distance].kilometers.round
      distance_word = 'km'
    else
      distance = station[:current_distance].miles.round
      distance_word = ' miles'
    end

    state = station[:state_abbrev]
    "About #{distance}#{distance_word} away. #{station[:city]}, #{state}"
  end

  def select_station(args = {})
    App::Persistence['station'] = args[:station][:code]

    flurry_params = {station: args[:station][:code]}
    Flurry.logEvent("SELECTED_STATION", withParameters:flurry_params) unless Device.simulator?

    close
  end

  def close
    dismissModalViewControllerAnimated(true)
  end
end
