require 'script_importer/url_importer'
include ScriptImporter

class ImportController < ApplicationController

	before_action :authenticate_user!
	before_action :check_read_only_mode, except: [:index]

	def index
		@scripts_by_source = Script.joins(:authors).where(authors: { user_id: current_user.id }).where.not(script_sync_source_id: nil).includes([:script_sync_source, :script_sync_type])
		@scripts_by_source = @scripts_by_source.group_by{|script| script.script_sync_source}
	end

	def add
		importer = ScriptImporter::IMPORTERS.select{|i| i.sync_source_id == params[:sync_source_id].to_i}.first
		@results = {:new => [], :failure => [], :needsdescription => [], :existing => []}
		sync_ids = nil
		if params[:sync_ids].nil?
			sync_ids = params[:sync_urls].split(/[\n\r]+/)
		else
			sync_ids = params[:sync_ids]
		end
		sync_ids.each do |sync_id|
			provided_description = params["needsdescription-#{sync_id}"]
			result, script, message = importer.generate_script(sync_id, provided_description, current_user, (params['sync-type'].nil? ? 1 : params['sync-type']))
			case result
				when :needsdescription
					@results[:needsdescription] << script
				when :failure, :notuserscript
					@results[:failure] << "#{importer.sync_id_to_url(sync_id)} - #{message}"
				when :success
					existing_scripts = Script.where(['script_sync_source_id = ? and sync_identifier = ?', importer.sync_source_id, sync_id])
					if !existing_scripts.empty?
						@results[:existing] << existing_scripts.first
					elsif script.save
						@results[:new] << script
					else
						@results[:failure] << "Could not save."
					end
			end
		end
	end

end
