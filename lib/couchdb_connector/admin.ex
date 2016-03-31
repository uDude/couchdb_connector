defmodule Couchdb.Connector.Admin do
  @moduledoc """
  The Admin module provides functions to create and update users in
  the CouchDB server given by the database properties.

  ## Examples

      db_props = %{protocol: "http", hostname: "localhost",database: "couchdb_connector_test", port: 5984}
      %{database: "couchdb_connector_test", hostname: "localhost", port: 5984, protocol: "http"}

      Couchdb.Connector.Admin.create_user(db_props, "jan", "relax", ["couchdb contributor"])
      {:ok,
       "{\"ok\":true,\"id\":\"org.couchdb.user:jan\",\"rev\":\"1-1d509578d1bc8cba3a6690fca5e7a9fd\"}\n",
       [{"Server", "CouchDB/1.6.1 (Erlang OTP/18)"},
        {"Location", "http://localhost:5984/_users/org.couchdb.user:jan"},
        {"ETag", "\"1-1d509578d1bc8cba3a6690fca5e7a9fd\""},
        {"Date", "Thu, 31 Mar 2016 21:50:04 GMT"},
        {"Content-Type", "text/plain; charset=utf-8"}, {"Content-Length", "83"},
        {"Cache-Control", "must-revalidate"}]}

      Couchdb.Connector.Admin.create_user(db_props, "jan", "relax", ["couchdb contributor"])
      {:error,
        "{\"error\":\"conflict\",\"reason\":\"Document update conflict.\"}\n",
        [{"Server", "CouchDB/1.6.1 (Erlang OTP/18)"},
         {"Date", "Thu, 31 Mar 2016 21:50:06 GMT"},
         {"Content-Type", "text/plain; charset=utf-8"}, {"Content-Length", "58"},
         {"Cache-Control", "must-revalidate"}]}

      Couchdb.Connector.Admin.user_info(db_props, "jan")
      {:ok,
        "{\"_id\":\"org.couchdb.user:jan\",\"_rev\":\"1-...\",
          \"password_scheme\":\"pbkdf2\",\"iterations\":10,\"type\":\"user\",
          \"roles\":[\"couchdb contributor\"],\"name\":\"jan\",
          \"derived_key\":\"a294518...\",\"salt\":\"70869...\"}\n"}

      Couchdb.Connector.Admin.destroy_user(db_props, "jan")
      {:ok,
        "{\"ok\":true,\"id\":\"org.couchdb.user:jan\",\"rev\":\"2-429e8839208ed64cd58eae75957cc0d4\"}\n"}

      Couchdb.Connector.Admin.user_info(db_props, "jan")
      {:error, "{\"error\":\"not_found\",\"reason\":\"deleted\"}\n"}

      Couchdb.Connector.Admin.destroy_user(db_props, "jan")
      {:error, "{\"error\":\"not_found\",\"reason\":\"deleted\"}\n"}

  """

  use Couchdb.Connector.Types

  alias Couchdb.Connector.Headers
  alias Couchdb.Connector.UrlHelper
  alias Couchdb.Connector.ResponseHandler, as: Handler

  @doc """
  Create a new user with given username, password and roles. In case of success,
  the function will respond with {:ok, body, headers}. In case of failures (e.g.
  if user already exists), the response will be {:error, body, headers}.
  """
  @spec create_user(db_properties, String.t, String.t, user_roles_list) :: String.t
  def create_user db_props, username, password, roles \\ [] do
    db_props
    |> UrlHelper.user_url(username)
    |> do_create_user(to_json(username, password, roles))
    |> Handler.handle_put(_include_headers = true)
  end

  defp do_create_user url, json do
    HTTPoison.put! url, json, [ Headers.json_header ]
  end

  defp to_json username, password, roles do
    Poison.encode! %{"name" => username, "password" => password,
                     "roles" => roles, "type" => "user"}
  end

  @doc """
  Returns the public information for the given user or an error in case the
  user does not exist.
  """
  @spec user_info(db_properties, String.t) :: String.t
  def user_info db_props, username do
    db_props
    |> UrlHelper.user_url(username)
    |> HTTPoison.get!
    |> Handler.handle_get
  end

  @doc """
  Deletes the given user from the database server or returns an error in case
  the user cannot be found.
  """
  @spec destroy_user(db_properties, String.t) :: String.t
  def destroy_user db_props, username do
    case user_info(db_props, username) do
      {:ok, user_json} ->
        user = Poison.decode! user_json
        do_destroy_user(db_props, username, user["_rev"])
      error -> error
    end
  end

  defp do_destroy_user db_props, username, rev do
    db_props
    |> UrlHelper.user_url(username)
    |> do_http_delete(rev)
    |> Handler.handle_delete
  end

  defp do_http_delete url, rev do
    HTTPoison.delete! url <> "?rev=#{rev}"
  end
end