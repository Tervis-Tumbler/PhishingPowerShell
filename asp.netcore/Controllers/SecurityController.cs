using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace asp.netcore.Controllers
{
    public class SecurityController : Controller
    {
        public IActionResult Validation()
        {
            return View();
        }
    }
}
