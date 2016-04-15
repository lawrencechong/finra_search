require 'pry'

class HomeController < ApplicationController
	
	def index
	end

	def search
		codes = params[:search]
		@results = Finra.search(codes)
		# @results = Finra.to_csv(@results[0])
		# binding.pry
		respond_to do |format|
  			format.js 
  			format.html
		end
	end
	
end