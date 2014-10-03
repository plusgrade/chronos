package com.airbnb.scheduler.api

import java.util.logging.Logger
import javax.servlet._
import javax.servlet.http.{HttpServletResponse, HttpServletRequest}
import com.airbnb.scheduler.config.SchedulerConfiguration
import com.google.inject.Inject

/**
 * Simple filter that sets CORS headers.
 * @author Jim Nidositko (drawn from: http://stackoverflow.com/questions/16351849/origin-is-not-allowed-by-access-control-allow-origin-how-to-enable-cors-using)
 */
class CorsFilter @Inject()(val configuration: SchedulerConfiguration) extends Filter {
  def init(filterConfig: FilterConfig) {}

  val log = Logger.getLogger(getClass.getName)

  def doFilter(rawRequest: ServletRequest,
               rawResponse: ServletResponse,
               chain: FilterChain) {
    if (rawResponse.isInstanceOf[HttpServletResponse]) {
      val response = rawResponse.asInstanceOf[HttpServletResponse]
      addHeadersFor200Response(response);
    }
    chain.doFilter(rawRequest, rawResponse);
  }

  def addHeadersFor200Response(response: HttpServletResponse){
    log.config( "Setting Access-Control-Allow-Origin to: " + configuration.allowOrigin());
    response.addHeader("Access-Control-Allow-Origin", configuration.allowOrigin());
    response.addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE, HEAD");
    response.addHeader("Access-Control-Allow-Headers", "X-PINGOTHER, Origin, X-Requested-With, Content-Type, Accept");
    response.addHeader("Access-Control-Max-Age", "1728000");
  }

  def destroy() {
    //NO-OP
  }
}
