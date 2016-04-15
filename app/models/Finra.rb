require 'nokogiri'
require 'open-uri'
require 'pry'

class Finra

	def self.search search

		codes = search.split(",").map{ |e| e.strip }

		result_hashes=[]
		codes.each{ |code|
			# binding.pry
			# Fetch and parse HTML document for a broker
			doc = Nokogiri::HTML(open('http://brokercheck.finra.org/Individual/Summary/' + code))
			if !doc.css('.summarydisplayname').text.empty? 
				begin
					result_hashes.push( Finra.broker_search(doc))
					next					
				rescue Exception => e
					result_hashes.push( nil )
				end

			end

			# Fetch and parse HTML document for a firm
			doc = Nokogiri::HTML(open('http://brokercheck.finra.org/Firm/Summary/' + code))
			if !doc.css('.summarydisplayname').text.empty? 
				begin
					result_hashes.push( Finra.firm_search(doc))
					next
				rescue
					result_hashes.push( nil )
				end
			else
				# Code is invalid
				result_hashes.push( nil )
			end	
		}
		# binding.pry
		return result_hashes

	end

	def self.firm_search doc

		hash = {}

		hash[:name] = doc.css('.summarydisplayname').text.gsub(/\s+/, ' ').strip
		hash[:id] = doc.css('.summarydisplaycrd.text-nowrap').text.gsub(/\s+/, ' ').gsub('(', '').gsub(')', '').strip
		hash[:titles] = doc.css('.summarybizcardsectionNoborder .bcrow .summaryBizcardtext.summarybizcardsectiondetail').text.gsub(/\s+/, ' ').strip

		## Disclosures
		disclosures = {}
		doc.css('.firmdisctablerow .FirmNestedListItemColor div').each_with_index{ |item,index|
			if index %2 == 0
				type = item.text.gsub(/\s+/, ' ').strip 
				amount = doc.css('.firmdisctablerow .FirmNestedListItemColor div')[index + 1].text.gsub(/\s+/, ' ').strip
				disclosures[type.to_sym] = amount
			end
		}
		hash[:disclosures] = disclosures

		## Firm Information

		office_information = {}

		office_information[:info] = doc.css('.bcrow.SummarySectionColor.left-border')[2].css('.summarysectionrightpanel div')[0].text.gsub(("\r\n"), "").strip.gsub(/\s+/, ' ')
		office_information[:Fiscal_Enddate] = doc.css('.bcrow.SummarySectionColor.left-border')[2].css('.summarysectionrightpanel div')[24].text.gsub(("\r\n"), "").strip
		office_information[:Fiscal_location] = doc.css('.bcrow.SummarySectionColor.left-border')[2].css('.summarysectionrightpanel div')[25].text.gsub(("\r\n"), "").strip

		doc.css('.firmprofilecell').each_with_index{|item,index|
			if index % 2 == 0
				office_information[item.text.gsub(/\s+/, ' ').strip.to_sym] = doc.css('.firmprofilecell')[index + 1].text.gsub(/\s+/, ' ').strip
			end
		}

		owners_officers = {}
		doc.css("div div.bcrow.FirmNestedListItemColor .Padding15").each{|item|
			arr = item.text.split("\r\n")
			arr = arr.map{ |e| e.strip }.reject { |c| c.empty? }.map { |e| e.gsub(/^- /, '') }

			owners_officers[arr[0].strip.to_sym] = arr[1..-1]
		}
		hash[:Office_information] = office_information

		## Firm Opertations

		opps_arr = doc.css('#rgstnAndExamsTable .summarysectionrightpanel .NoPadding').text.split(".").map{ |e| e.gsub(/\s+/, ' ') }.map{ |e| e.strip }.reject { |c| c.empty? }
		hash[:Firm_Operations] = opps_arr
		info = doc.css('#rgstnAndExamsTable .summarysectionrightpanel td').text.split("\r\n").map{ |e| e.strip }.reject { |c| c.empty? }
		states = info[4..-1].uniq![0..-5]
		info = info[0..3]
		hash[info[0].to_sym] = info[1..2]
		hash[info[0].to_sym].push({info[3] => states})

		return hash
	end

	def self.broker_search doc
		hash = {}

		name = doc.css('.summarydisplayname').text
		alternate_name = doc.css('.bcrow.SummarySectionColor .searchresulttext :nth-child(2)')[1].text.gsub(/\s+/, ' ').strip.gsub('Alternate Names: ' , '')
		crd = doc.css('.summarydisplaycrd')

		# titles = []
		# doc.css('.summarybizcardsectionNoborder .summaryBizcardtext.summarybizcardsectiondetail .summaryheadertext').each{|item|
		# 	titles.push(item.text.gsub(/\s+/, ' ').strip)
		# }
		titles = doc.css('.summarybizcardsectionNoborder .summaryBizcardtext.summarybizcardsectiondetail .summaryheadertext').text.gsub(/\s+/, ' ').strip

		## Current Registrations

		if !doc.css('#registrationSection :nth-child(2) div .currregsecondcolumn').empty?
				company = doc.css('#registrationSection :nth-child(2) div .currregsecondcolumn').children[1].children
			crd = company[1].children.text
			curr_company = company.first.text.gsub(/\s+/, ' ').strip + crd + ")"


			locations = []

			doc.css('#registrationSection :nth-child(2) div .currregsecondcolumn div div').each_with_index do |item,index|
				locations.push(item.text.gsub(/\s+/, ' ').strip) if index % 2 == 0
			end

			curr_date = ""
			doc.css('#registrationSection :nth-child(2) div .currregfirstcolumn').each do |item|
				curr_date = item.text.gsub(/\s+/, ' ').strip
			end

			curr_reg = { curr_date.to_sym => [curr_company, locations]}

		else
			curr_company = doc.css('#registrationSection div')[2].text.gsub(/\s+/, ' ').strip

		end



		## Previous Registrations

		company = []

		doc.css('#prevregistrationSection :nth-child(2) div .prevregsecondcolumn').each do |item|
			company.push(item.text.gsub(/\s+/, ' ').strip)
		end

		dates = []
		doc.css('#prevregistrationSection :nth-child(2) div .prevregfirstcolumn').each do |item|
			dates.push(item.text.gsub(/\s+/, ' ').strip)
		end

		prev_reg = {}
		dates.each_with_index{|date,index|
			prev_reg[date.to_sym] = company[index]
		}


		disclosures = {}
		if !doc.css('#disclosuretable').empty?

			doc.css('#disclosuretable tr')[1..-1].each_with_index{|item,index|
				if index % 2 == 0		
					date = item.children.children.children.children[0].text.gsub(/\s+/, ' ').strip
					description = item.children.children.children.children[1].text.gsub(/\s+/, ' ').strip
					disclosures[date.to_sym] = description
				end
			}
		else
			disclosures[:notice] = 'This broker has no disclosure events.'
		end

		## Registrations Exam Table
		exams_passed = doc.css('#rgstnAndExamsTable .summarysectionrightpanel #examSection .summaryheadertext').text
		exams = {}
		doc.css('#rgstnAndExamsTable .summarysectionrightpanel #examSection .NestedListItemColor').each { |item|  
			exams[item.children[1].text.to_sym] = []

			item.children.children.children.each_with_index{|sub_exam, index|
				counter = index % 3 
				if counter == 0
					exam_subtype = sub_exam.text.gsub(/\s+/, ' ').strip
					exam_series = item.children.children.children[index  + 1].text.gsub(/\s+/, ' ').strip
					exam_date = item.children.children.children[index + 2].text.gsub(/\s+/, ' ').strip
					exams[item.children[1].text.to_sym].push([exam_subtype,exam_series,exam_date])
				else 
					next
				end			
			}

		}

		## State Registrations
		state_reg = {}
		summary_header = doc.css('#rgstnAndExamsTable .summarysectionrightpanel .summaryheadertext')[1].text.gsub(/\s+/, ' ').strip
		state_reg[:summary_header] = summary_header
		if (!doc.css('#rgstnAndExamsTable .summarysectionrightpanel .statelistcol li').empty?)
			sub_summary = doc.css('#rgstnAndExamsTable .summarysectionrightpanel .summaryheadertext')[2].text
			states_territories_registered = []
			doc.css('#rgstnAndExamsTable .summarysectionrightpanel .statelistcol li').each{|item|
				states_territories_registered.push(item.text.strip)
			}
			states_territories_registered.uniq!
			state_reg[:sub_summary] = sub_summary
			state_reg[:states] = states_territories_registered
		end

		hash[:name] = name
		hash[:id] = crd
		hash[:alternate_name] = alternate_name
		hash[:titles] = titles
		hash[:current_company] = curr_reg
		hash[:past_companies] = prev_reg
		hash[:exams_passed] = exams
		hash[:registrations] = state_reg

		return hash
	end

	def self.to_csv (h)
		require 'csv'
		# CSV.open("data.csv", "wb") {|csv| h.to_a.each {|elem| csv << elem} }
		# file = CSV.generate {|csv| h.to_a.each {|elem| csv << elem} }
		# send_data file
	end

	# individuals
	# search("1327992")
	# search("5100942")
	# search("1023859")

	# firms
	# search("20999")
	# search("816")

end


