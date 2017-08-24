class ApiController < ApplicationController
  respond_to :html, :json

  require 'rest-client'
  require 'json'

  def summoner
    summoner_data = RestClient.get("https://na1.api.riotgames.com/lol/summoner/v3/summoners/by-name/"+params["summoner"]+"?itemListData=all&api_key="+Rails.application.secrets.riot_api_key)
    summoner_data = JSON.parse(summoner_data)
    match_list_data = RestClient.get("https://na1.api.riotgames.com/lol/match/v3/matchlists/by-account/"+summoner_data['accountId'].to_s+"/recent?itemListData=all&api_key="+Rails.application.secrets.riot_api_key)
    match_list_data = JSON.parse(match_list_data)['matches']
    summoner_ranks = summonerRanks(summoner_data['id'].to_s)
    champ_masteries = championMastery(summoner_data['id'].to_s)[0..4]
    champ_masteries.each {|p| p[:champion] = getChampionNameById(p['championId']) }
    match_data = []

    match_list_data[0..2].each do |item|
      match = RestClient.get("https://na1.api.riotgames.com/lol/match/v3/matches/"+item['gameId'].to_s+"?forAccountId="+summoner_data['accountId'].to_s+"&api_key="+Rails.application.secrets.riot_api_key)
      match = JSON.parse(match)

      participantId = getParticipantId(match)
      participant = match['participants'].select { |x| x['participantId'] == participantId }[0]
      teamId = participant['teamId']
      championId = participant['championId']

      match['kda'] = {'kills': participant['stats']['kills'], 'deaths': participant['stats']['deaths'], 'assists': participant['stats']['assists']}
      match['champion'] = getChampionNameById(championId)
      match['win'] = match['teams'].select { |x| x['teamId'] == teamId }[0]['win']
      match['stats'] = participant['stats']
      match['summoner_spells'] = findSummonerSpells(participant)

      match['participants'].each do |p|
        p["champion"] = getChampionNameById(p['championId'])
      end

      match['teams'].each do |team|
        team['kills'] = team['deaths'] = team['assists'] = 0
        match['participants'].each do |p|
          p['summoner_spells'] = findSummonerSpells(p)
          p['identity'] = match['participantIdentities'].select { |x| x['participantId'] == p['participantId'] }[0]
          if !p['identity'].include?('player') 
            p['identity'] = {'player': {}} 
          end
          if p['teamId'] == team['teamId']
            team['kills'] += p['stats']['kills']
            team['deaths'] += p['stats']['deaths']
            team['assists'] += p['stats']['assists']
          end
        end
      end

      match_data.push(match)
    end

    return render json: {
      'match_data': match_data, 
      'summoner_ranks': summoner_ranks, 
      'champ_masteries': champ_masteries
    }
  end

  def summonerRanks(summonerId)
    summoner_rank_data = RestClient.get("https://na1.api.riotgames.com/lol/league/v3/positions/by-summoner/"+summonerId+"?api_key="+Rails.application.secrets.riot_api_key)
    return JSON.parse(summoner_rank_data)
  end

  def championMastery(summonerId)
    champ_mast_data = RestClient.get("https://na1.api.riotgames.com/lol/champion-mastery/v3/champion-masteries/by-summoner/"+summonerId+"?api_key="+Rails.application.secrets.riot_api_key)
    return JSON.parse(champ_mast_data)
  end

  def getParticipantId(match)
    return match['participantIdentities'].select { |x| x.include?('player') }[0]['participantId']
  end

  def findSummonerSpells(participant)
    summoner_spells = []
    summoner_spells.push(Api::SUMMONER_SPELLS_MAP.select { |x| x[:id] == participant['spell1Id'] }[0][:key])
    summoner_spells.push(Api::SUMMONER_SPELLS_MAP.select { |x| x[:id] == participant['spell2Id'] }[0][:key])
    return summoner_spells
  end

  def getChampionNameById(championId)
    champion = ""
    Api::CHAMPION_MAP.each do |idx,val|
      if val[:id] == championId
        champion = val[:key]
      end
    end
    return champion
  end
end