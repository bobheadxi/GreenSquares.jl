import GitHub
import CSV
import DataFrames
import JSON
import Dates

function incrementDict(dict::Dict{String, Int}, key::String, count::Int)
    if !haskey(dict, key)
        dict[key] = count
    else
        dict[key] += count
    end
end

function writeCSV(d::Dict, filename::String)
    df = DataFrame(; [symbol(k)=>v for (k,v) in d]...)
    CSV.write(df, filename)
end

function exec()
    # Make API request for repos
    token = ENV["GITHUB_AUTH"]
    auth = GitHub.authenticate(token)
    repos = GitHub.repos(
        "ubclaunchpad", true,
        auth=auth,
        params=Dict{String,String}("type" => "all")
    )[1]

    # stats
    languages = Dict{String,Int}()
    contributors = Dict{String, Int}()
    contributions = Dict{String, Int}()
    commits = Dict{String,Int}()
    prs = Dict{String,Int}()
    stars = 0

    # gather data - TODO: pagination
    for i = 1:length(repos)
        cur = repos[i]
        print("Processing " * cur.full_name * " | ")

        # language
        incrementDict(languages, cur.language, 1)

        # stars
        print(string(cur.stargazers_count) * " stars | ")
        if cur.stargazers_count != nothing
            stars += cur.stargazers_count
        end

        # contributors
        c = GitHub.contributors(cur.full_name, auth=auth)[1]
        print(string(length(c)) * " contributors | ")
        for j = 1:length(c)
            incrementDict(contributors, c[j]["contributor"].login, 1)
            incrementDict(contributions, c[j]["contributor"].login, c[j]["contributions"])
        end

        # commits
        c = GitHub.stats(cur.full_name, "participation", auth=auth)
        data = JSON.parse(String(c.body))["all"]
        now = Dates.today()
        print("added commits | ")
        for j = 1:length(data)
            ago = length(data) - j
            period = now - Dates.Week(ago)
            incrementDict(commits, Dates.format(period, "yyyy-mm"), data[j])
        end

        # pull requests
        p = GitHub.pull_requests(cur.full_name, auth=auth,
            params=Dict{String,String}("state" => "all"))[1]
        print(string(length(p)) * " pull requests | ")
        for j = 1:length(p)
            created = p[j].created_at
            incrementDict(prs, Dates.format(created, "yyyy-mm"), 1)
        end

        println("")
    end

    println("Data curated")
    println("Stars: " * string(stars))

    # dataframes for CSVs
    println("Generating CSVs")
    writeCSV(languages, "languages.csv")
    writeCSV(contributors, "contributors.csv")
    writeCSV(contributions, "contributions.csv")
    writeCSV(commits, "commits.csv")
    writeCSV(prs, "pullrequests.csv")
end

# let's go!
exec()
