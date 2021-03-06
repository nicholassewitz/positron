_ = require 'underscore'
Joi = require 'joi'
Joi.objectId = require('joi-objectid') Joi
schema = require './schema'
{ ObjectId } = require 'mongojs'
moment = require 'moment'

@toQuery = (input, callback) ->
  Joi.validate input, schema.querySchema, { stripUnknown: true }, (err, input) ->
    return callback err if err
    # Separate "find" query from sort/offest/limit
    { limit, offset, sort } = input
    query = _.omit input, 'limit', 'offset', 'sort', 'artist_id', 'artwork_id', 'super_article_for',
      'fair_ids', 'fair_programming_id', 'fair_artsy_id', 'fair_about_id', 'partner_id', 'auction_id', 'show_id', 'q', 'all_by_author', 'section_id', 'tags'
    # Type cast IDs
    # TODO: https://github.com/pebble/joi-objectid/issues/2#issuecomment-75189638
    query.author_id = ObjectId input.author_id if input.author_id
    query.fair_id = { $in: _.map(input.fair_ids, ObjectId) } if input.fair_ids
    query.fair_programming_ids = ObjectId input.fair_programming_id if input.fair_programming_id
    query.fair_artsy_ids = ObjectId input.fair_artsy_id if input.fair_artsy_id
    query.fair_about_ids = ObjectId input.fair_about_id if input.fair_about_id
    query.partner_ids = ObjectId input.partner_id if input.partner_id
    query.show_ids = ObjectId input.show_id if input.show_id
    query.auction_id = ObjectId input.auction_id if input.auction_id
    query.section_ids = ObjectId input.section_id if input.section_id
    query.biography_for_artist_id = ObjectId input.biography_for_artist_id if input.biography_for_artist_id
    query.featured_artwork_ids = ObjectId input.artwork_id if input.artwork_id
    query.tags = { $in: input.tags } if input.tags

    # Convert query for super article for article
    query['super_article.related_articles']= ObjectId(input.super_article_for) if input.super_article_for

    # Only add the $or array for queries that require it (blank $or array causes problems)
    query.$or ?= [] if input.artist_id or input.all_by_author

    # Convert query for articles by author
    query.$or.push(
      { author_id: ObjectId(input.all_by_author) }
      { contributing_authors: { $elemMatch: { id: ObjectId input.all_by_author} } }
    ) if input.all_by_author

    # Convert query for articles featured to an artist or artwork
    query.$or.push(
      { primary_featured_artist_ids: ObjectId(input.artist_id) }
      { featured_artist_ids: ObjectId(input.artist_id) }
      { biography_for_artist_id: ObjectId(input.artist_id) }
    ) if input.artist_id

    # Allow regex searching through the q param
    query.thumbnail_title = { $regex: new RegExp(input.q, 'i') } if input.q

    # Look for articles with scheduled dates before the given date
    query.scheduled_publish_at = { $lt: moment(input.scheduled_publish_at).toDate() } if input.scheduled_publish_at

    callback null, query, limit, offset, sortParamToQuery(sort)

sortParamToQuery = (input) ->
  return { updated_at: -1 } unless input
  sort = {}
  for param in input.split(',')
    if param.substring(0, 1) is '-'
      sort[param.substring(1)] = -1
    else
      sort[param] = 1
  sort
